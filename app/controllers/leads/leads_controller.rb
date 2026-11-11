module Leads
  # The leads: a table (filtered by what's open, stage, owner and source, with the bulk bar) or a
  # board of open leads by stage, each lead's page, and adding, changing and deleting one by hand.
  # Anyone on the team works leads; deleting needs delete_records (Lost keeps the history instead).
  class LeadsController < ApplicationController
    allow_staff
    require_permission :delete_records, only: :destroy

    SHOWS = { "open" => "Open", "attention" => "Needs attention", "won" => "Won", "lost" => "Lost", "all" => "All" }.freeze
    LEAD_PARAMS = { name: "string", email: "string", phone: "string", company: "string", website: "string", message: "text",
                    source: "string", value_cents: "integer", owner_id: "string", stage_id: "integer", next_step: "string", next_step_on: "date" }.freeze

    agent_tool :list_leads, on: :index, title: "List leads",
      description: "Leads, newest first. show: open (default), attention (open ones with an overdue next step or none past the first stage), won, lost or all. " \
        "owner: me, nobody (unassigned), or someone's id or name. stage: a stage's id (show_leads_settings lists them). source: where they came from. q: words to match.",
      params: { show: SHOWS.keys, owner: "string", stage: "integer", source: "string", q: "string" }, next_tools: %i[show_lead claim_lead]
    agent_tool :show_lead, on: :show, title: "Show a lead",
      description: "A lead with its contact details, where it came from (source and the form's details), stage, owner, value, next step, and its history: calls, emails, meetings and notes logged, and every change.",
      next_tools: %i[log_lead_activity update_lead win_lead lose_lead]
    agent_tool :create_lead, on: :create, title: "Add a lead",
      description: "Someone who might buy, added by hand (a call, an introduction, a card from an event): at least a name, an email or a company. " \
        "It lands at the first stage unless stage_id says otherwise; owner_id: me, someone's id or name, or blank for nobody. value_cents: what it may be worth, in cents. " \
        "Whoever's told about new leads hears of it.",
      params: { lead: LEAD_PARAMS }, next_tools: %i[show_lead log_lead_activity]
    agent_tool :update_lead, on: :update, title: "Change a lead",
      description: "Its details, owner (owner_id: me, someone's id or name, nobody), stage (stage_id, open leads only), value_cents, or next step (next_step, what happens next, and next_step_on, by when). Only what's given changes. Each change goes in its history; giving it to someone emails them.",
      params: { lead: LEAD_PARAMS }, next_tools: %i[show_lead]
    agent_tool :delete_lead, on: :destroy, title: "Delete a lead",
      description: "Gone for good, with its history. To keep the record, lose it instead (lose_lead, with reason spam for junk)."

    before_action :set_lead, only: %i[show edit update destroy]

    def index
      @view = index_view(extra: %w[board])
      @show = params[:show].presence_in(SHOWS.keys) || "open"
      @owner = params[:owner].presence || "anyone"
      @stage = Stage.find_by(id: params[:stage]) if params[:stage].present?
      @source = params[:source].presence
      @stages = Stage.ordered.to_a
      @page_title = "Leads"

      if @view == "board"
        @board = board_leads
      else
        @leads = paginate(filtered(Lead.includes(:stage, :owner, :client)).newest)
      end
    end

    def show
      @page_title = @lead.display_name
      @activities = @lead.activities.includes(:user).limit(200).to_a
      @stage_names = Stage.pluck(:id, :name).to_h
      @people = User.where(id: @activities.flat_map { [ it.data["from"], it.data["to"] ] if it.kind == "owner" }.compact).to_h { [ it.id, it.display_name ] }
    end

    def new
      @lead = Lead.new(owner: Current.user.person)
      @page_title = "Add a lead"
    end

    def create
      @lead = Lead.new(lead_params.merge(created_by: Current.user))
      @lead.source ||= "Added by hand"
      if @lead.save
        redirect_to lead_path(@lead), notice: "#{@lead.display_name} added, at #{@lead.stage&.name}#{", for #{@lead.owner.display_name}" if @lead.owner}."
      else
        @page_title = "Add a lead"
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @page_title = "Change #{@lead.display_name}"
    end

    def update
      attributes = lead_params
      raise Lead::Refused, "It’s #{@lead.state}: reopen it to move it." if attributes.key?(:stage_id) && !@lead.open? && attributes[:stage_id].to_i != @lead.stage_id

      if @lead.update(attributes)
        redirect_back fallback_location: lead_path(@lead), notice: update_notice(attributes)
      elsif params[:inline]
        redirect_back fallback_location: lead_path(@lead), alert: @lead.errors.full_messages.to_sentence
      else
        @page_title = "Change #{@lead.display_name}"
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @lead.destroy!
      redirect_to leads_path, notice: "#{@lead.display_name} deleted, with its history."
    end

    private
      def lead_params
        attributes = params.expect(lead: %i[name email phone company website message source value_cents owner_id stage_id next_step next_step_on])
        if attributes.key?(:owner_id)
          value = attributes[:owner_id]
          owner = owner_from(value)
          raise Lead::Refused, "Nobody on the team matches “#{value}”." if owner.nil? && value.present? && value != "nobody"

          attributes[:owner_id] = owner&.id
        end
        attributes
      end

      def update_notice(attributes)
        if attributes.key?(:owner_id) then @lead.owner ? "#{@lead.owner.display_name} has #{@lead.display_name}." : "#{@lead.display_name} is unassigned."
        elsif attributes.key?(:stage_id) then "#{@lead.display_name} is at #{@lead.stage&.name}."
        elsif attributes.key?(:next_step) || attributes.key?(:next_step_on) then @lead.next_step || @lead.next_step_on ? "Next step saved." : "Next step cleared."
        else "#{@lead.display_name} saved."
        end
      end

      def filtered(scope)
        scope = case @show
        when "open" then scope.open
        when "attention" then scope.needing_attention
        when "won" then scope.won
        when "lost" then scope.lost
        else scope
        end
        scope = scope.where(stage: @stage) if @stage
        scope = scope.where(source: @source) if @source
        case @owner
        when "anyone" then scope
        when "nobody" then scope.unassigned
        else (owner = owner_from(@owner)) ? scope.owned_by(owner) : scope.none
        end
      end

      # Open leads by stage, at most BOARD_LIMIT a column, the soonest next step first: one query
      # for the counts and one for the cards.
      BOARD_LIMIT = 100
      def board_leads
        show = @show
        @show = "open" unless @show == "attention"
        scope = text_filtered(filtered(Lead.all))
        @show = show
        counts = scope.group(:stage_id).count
        cards = scope.includes(:owner, :stage, :client).order(Arel.sql("leads_leads.next_step_on IS NULL, leads_leads.next_step_on, leads_leads.created_at DESC"))
                     .limit(BOARD_LIMIT * [ @stages.size, 1 ].max * 4).to_a.group_by(&:stage_id)
        @stages.to_h { |stage| [ stage, { leads: Array(cards[stage.id]).first(BOARD_LIMIT), count: counts.fetch(stage.id, 0) } ] }
      end
  end
end
