module Leads
  # Each stage's plan, in Settings › Plugins › Leads: the steps a lead gets on arriving there, each
  # due some days on, and the email template it starts from. Changing a plan changes what leads get
  # from then on.
  class PlaybookStepsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    STEP_PARAMS = { stage_id: "integer!", title: "string!", days_after: "integer", template_id: "integer" }.freeze
    agent_tool :create_lead_plan_step, on: :create, title: "Add a step to a stage's plan",
      description: "When a lead arrives at stage_id it gets this step (title), due days_after days later (0: the same day), starting from template_id if given.",
      params: { playbook_step: STEP_PARAMS }, next_tools: %i[show_leads_settings]
    agent_tool :update_lead_plan_step, on: :update, title: "Change a step in a stage's plan",
      description: "Its title, days_after or template_id (blank for none). Leads already given it keep theirs.",
      params: { playbook_step: STEP_PARAMS.except(:stage_id).merge(title: "string") }, next_tools: %i[show_leads_settings]
    agent_tool :delete_lead_plan_step, on: :destroy, title: "Take a step out of a stage's plan",
      description: "Leads already given it keep theirs."

    def create
      step = PlaybookStep.new(step_params)
      if step.save
        redirect_to leads_settings_path(anchor: "plans"), notice: "#{step.stage.name}: #{step.title}, #{step.when_label}."
      else
        redirect_to leads_settings_path(anchor: "plans"), alert: step.errors.full_messages.to_sentence
      end
    end

    def update
      step = PlaybookStep.find(params[:id])
      if step.update(step_params.except(:stage_id))
        redirect_to leads_settings_path(anchor: "plans"), notice: "#{step.title} saved."
      else
        redirect_to leads_settings_path(anchor: "plans"), alert: step.errors.full_messages.to_sentence
      end
    end

    def destroy
      step = PlaybookStep.find(params[:id])
      step.destroy!
      redirect_to leads_settings_path(anchor: "plans"), notice: "#{step.title} is out of the #{step.stage.name} plan."
    end

    private
      def step_params
        attributes = params.expect(playbook_step: %i[stage_id title days_after template_id])
        attributes[:template_id] = attributes[:template_id].presence if attributes.key?(:template_id)
        attributes
      end
  end
end
