module Leads
  class LeadsController < ApplicationController
    PER_PAGE = 50

    allow_staff
    require_permission :delete_records, only: :destroy
    agent_tool :list_leads, on: :index, title: "List leads",
      description: "Leads, most recently active first. stage: open (the default: not yet a customer, lost or spam), new, nurturing, qualified, customer, lost, spam or all (everything but spam). owner: me, or a person. q: part of a name, email or company.",
      params: { stage: "string", owner: "string", q: "string" }, next_tools: %i[show_lead create_lead]
    agent_tool :show_lead, on: :show, title: "Show a lead",
      description: "A lead with its details, score, timeline, tasks and email sequences.",
      next_tools: %i[add_lead_note add_lead_task update_lead enroll_lead convert_lead_to_client]
    agent_tool :create_lead, on: :create, title: "Add a lead",
      description: "Someone who might become a client: a name, email or phone is enough (someone who rang may have no email). stage: new (the default), nurturing, qualified, customer, lost or spam.",
      params: { lead: { email: "string", name: "string", phone: "string", company: "string", stage: Lead::STAGES, owner_id: "integer" } },
      next_tools: %i[add_lead_task enroll_lead]
    agent_tool :update_lead, on: :update, title: "Change a lead",
      description: "Its details, owner or stage. Moving it to customer or lost stops its email sequences; a stage can start the sequences triggered by it.",
      params: { lead: { email: "string", name: "string", phone: "string", company: "string", stage: Lead::STAGES, owner_id: "integer" } }
    agent_tool :delete_lead, on: :destroy, title: "Delete a lead",
      description: "Forgets the lead with its timeline, tasks, sequences and the emails sent to it. A client made from it stays."

    before_action :set_lead, only: %i[show edit update destroy]

    def index
      @stage = params[:stage].presence_in(Lead::STAGES + %w[open all]) || "open"
      @owner = params[:owner].presence
      scope = case @stage
      when "all" then Lead.not_spam
      when "open" then Lead.open
      else Lead.in_stage(@stage)
      end
      scope = scope.where(owner: @owner == "me" ? Current.user.person : @owner) if @owner
      scope = scope.matching(params[:q]) if params[:q].present?
      @page = [ params[:page].to_i, 1 ].max
      leads = scope.recent_first.includes(:owner)
      @leads = request.format.json? ? leads.limit(500).to_a : leads.offset((@page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @more = !request.format.json? && @leads.size > PER_PAGE
      @leads = @leads.first(PER_PAGE) unless request.format.json?
    end

    def show
      @activities = @lead.activities.includes(:user).limit(100)
      @tasks = @lead.tasks.includes(:assignee).order(Arel.sql("done_at IS NOT NULL")).in_due_order
      @enrollments = @lead.enrollments.includes(sequence: :steps).newest_first
    end

    def new
      @lead = Lead.new(owner: Current.user.person)
    end

    def create
      @lead = Lead.new(lead_params.merge(source: Current.agent? ? "agent" : "manual"))
      if @lead.save
        @lead.record_creation
        redirect_to lead_path(@lead), notice: "#{@lead.display_name} added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @lead.revise(lead_params)
        redirect_back fallback_location: lead_path(@lead), notice: "#{@lead.display_name} saved."
      elsif params[:from_page]
        redirect_back fallback_location: lead_path(@lead), alert: @lead.errors.full_messages.to_sentence
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @lead.destroy!
      redirect_to leads_path, notice: "#{@lead.display_name} deleted."
    end

    private
      def lead_params = params.expect(lead: %i[email name phone company stage owner_id])
  end
end
