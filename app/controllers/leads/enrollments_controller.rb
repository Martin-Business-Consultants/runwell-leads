module Leads
  class EnrollmentsController < ApplicationController
    allow_staff
    agent_tool :enroll_lead, on: :create, title: "Start an email sequence for a lead",
      description: "The sequence's emails go to the lead, each after its delay, while the sequence is on.",
      params: { enrollment: { sequence_id: "integer!" } }, confirm: "The lead will be emailed from this sequence."
    agent_tool :stop_lead_enrollment, on: :update, title: "Stop a lead's email sequence"

    before_action :set_lead

    def create
      sequence = Sequence.find(params.expect(enrollment: :sequence_id)[:sequence_id])
      if (refusal = @lead.enrollment_refusal(sequence))
        redirect_to lead_path(@lead), alert: refusal
      else
        @lead.enroll(sequence)
        redirect_to lead_path(@lead), notice: "#{@lead.display_name} started #{sequence.name}#{" (it’s off, so nothing sends until it’s on)" unless sequence.active?}."
      end
    end

    def update
      enrollment = @lead.enrollments.find(params[:id])
      enrollment.stop(user: Current.user)
      redirect_to lead_path(@lead), notice: "Stopped #{enrollment.sequence.name}."
    end
  end
end
