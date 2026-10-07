# frozen_string_literal: true

# Leads: the list (a tab per stage, search, bulk stage changes and deletes),
# a lead's page (its details, stage and owner, timeline, score, tasks and
# sequences), and adding one by hand. What a lead's page posts besides its
# details are resources under it (notes, tasks, score adjustments,
# enrollments).
module Leads
  class LeadsController < ::ApplicationController
    include PluginGated
    plugin :leads

    requires_capability "leads:read", only: [:index, :show]
    requires_capability "leads:write", only: [:new, :create, :update]
    requires_capability "leads:delete", only: :destroy

    before_action :set_lead, only: [:show, :update, :destroy]

    def index
      @stage = params[:stage].presence_in(Lead::STAGES)
      @owner = params[:owner].presence_in(%w[me none])
      @stage_counts = Lead.group(:stage).count
      @leads = paginate(filtered_leads)
    end

    def show
      load_lead_page
    end

    def new
      @lead = Lead.new(stage: "new", owner: Current.user)
    end

    def create
      @lead = Lead.new(lead_params.merge(source: "manual"))

      if @lead.save
        @lead.record_creation
        redirect_to lead_path(@lead), notice: "Lead added"
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      if @lead.revise(lead_params)
        redirect_to lead_path(@lead), notice: "Lead saved"
      else
        load_lead_page
        render :show, status: :unprocessable_content
      end
    end

    def destroy
      @lead.forget
      redirect_to leads_path, notice: "#{@lead.display_name} deleted, with everything on its timeline"
    end

    private

    def set_lead
      @lead = Lead.find(params[:id])
    end

    def lead_params
      params.require(:lead).permit(:email, :name, :phone, :company, :stage, :owner_id)
    end

    def filtered_leads
      scope = Lead.includes(:owner).search_list(search_term).recent_first
      scope = scope.in_stage(@stage) if @stage
      case @owner
      when "me" then scope.where(owner: Current.user)
      when "none" then scope.where(owner_id: nil)
      else scope
      end
    end

    def load_lead_page
      @activities = @lead.activities.includes(:user).limit(100)
      @tasks = @lead.tasks.includes(:assignee).order(Arel.sql("CASE WHEN done_at IS NULL THEN 0 ELSE 1 END")).in_due_order
      @enrollments = @lead.enrollments.includes(sequence: :steps).newest_first
      @sequences = Sequence.active.ordered
    end
  end
end
