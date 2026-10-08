module Leads
  class StepsController < ApplicationController
    require_permission :manage_sequences
    agent_tool :add_lead_sequence_email, on: :create, title: "Add an email to a lead sequence",
      description: "Sent delay_amount delay_unit (hours or days) after the lead joined, or after the email before. subject and body (HTML) may say {{name}}, {{first_name}}, {{email}} and {{company}}.",
      params: { step: { subject: "string!", body: "text", delay_amount: "integer", delay_unit: Step::DELAY_UNITS } }
    agent_tool :update_lead_sequence_email, on: :update, title: "Change an email of a lead sequence",
      description: "move: up or down, to change its place.",
      params: { step: { subject: "string", body: "text", delay_amount: "integer", delay_unit: Step::DELAY_UNITS }, move: %w[up down] }
    agent_tool :delete_lead_sequence_email, on: :destroy, title: "Delete an email from a lead sequence"

    before_action { @sequence = Sequence.find(params[:sequence_id]) }
    before_action :set_step, only: %i[edit update destroy]

    def create
      step = @sequence.steps.new(step_params)
      if step.save
        redirect_to leads_sequence_path(@sequence), notice: "Email #{step.number} added."
      else
        redirect_to leads_sequence_path(@sequence), alert: step.errors.full_messages.to_sentence
      end
    end

    def edit
    end

    def update
      if params[:move]
        @step.move(params[:move])
        redirect_to leads_sequence_path(@sequence), notice: "Moved “#{@step.subject}” #{params[:move] == "up" ? "up" : "down"}."
      elsif @step.update(step_params)
        redirect_to leads_sequence_path(@sequence), notice: "Email #{@step.number} saved."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @step.destroy!
      redirect_to leads_sequence_path(@sequence), notice: "Deleted “#{@step.subject}”."
    end

    private
      def set_step = @step = @sequence.steps.find(params[:id])
      def step_params = params.expect(step: %i[subject body delay_amount delay_unit])
  end
end
