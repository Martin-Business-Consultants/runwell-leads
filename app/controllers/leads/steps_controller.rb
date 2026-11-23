module Leads
  # A lead's plan, step by step: add one (what, by when), tick one done, open it again, change its
  # words or date, or take it off. The lead's next step follows its earliest open step.
  class StepsController < ApplicationController
    allow_staff
    agent_tool :add_lead_step, on: :create, title: "Add a step to a lead's plan",
      description: "Something to do on the lead by a date: title (what) and due_on (by when). The lead's next step is its earliest open step. " \
        "template_id: an email template it starts from (show_leads_settings lists them).",
      params: { step: { title: "string!", due_on: "date", template_id: "integer" } }, next_tools: %i[show_lead]
    agent_tool :update_lead_step, on: :update, title: "Change, tick off or reopen a step on a lead",
      description: "done: true when it's done (it counts as being in touch), false to open it again. title and due_on change it.",
      params: { step: { title: "string", due_on: "date", done: "boolean" } }, next_tools: %i[show_lead]
    agent_tool :remove_lead_step, on: :destroy, title: "Take a step off a lead's plan",
      description: "Gone from its plan. To say it happened, mark it done instead."

    before_action :set_lead
    before_action :set_step, only: %i[update destroy]

    def create
      attributes = params.expect(step: %i[title due_on template_id])
      raise Lead::Refused, "It’s #{@lead.state}: reopen it to plan more." unless @lead.open?

      step = @lead.add_step!(title: attributes[:title], due_on: attributes[:due_on].presence, template_id: attributes[:template_id])
      redirect_back fallback_location: lead_path(@lead), notice: "Planned: #{step.title}#{" by #{step.due_on.strftime("%b %-d")}" if step.due_on}."
    rescue ActiveRecord::RecordInvalid => error
      raise Lead::Refused, error.record.errors.full_messages.to_sentence
    end

    def update
      attributes = params.expect(step: %i[title due_on done])
      if attributes.key?(:done)
        done = ActiveModel::Type::Boolean.new.cast(attributes[:done])
        done ? @lead.complete_step!(@step) : @lead.reopen_step!(@step)
        return redirect_back(fallback_location: lead_path(@lead), notice: done ? done_notice : "#{@step.title} is open again.")
      end

      changes = attributes.slice(:title, :due_on).to_h
      changes["due_on"] = changes["due_on"].presence if changes.key?("due_on")
      raise Lead::Refused, @step.errors.full_messages.to_sentence unless @step.update(changes)

      @lead.sync_next_step!
      redirect_back fallback_location: lead_path(@lead), notice: "Step saved."
    end

    def destroy
      @step.destroy!
      @lead.sync_next_step!
      redirect_back fallback_location: lead_path(@lead), notice: "#{@step.title} is off the plan."
    end

    private
      def set_step = @step = @lead.steps.find(params[:id])

      def done_notice
        @lead.reload
        "Done: #{@step.title}." + (@lead.next_step ? " Next: #{@lead.next_step}#{" by #{@lead.next_step_on.strftime("%b %-d")}" if @lead.next_step_on}." : " Nothing else is planned.")
      end
  end
end
