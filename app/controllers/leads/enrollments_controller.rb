# frozen_string_literal: true

# Putting a lead in a sequence by hand, and taking it out (stopping its
# enrollment, which stays on the lead's page as stopped).
module Leads
  class EnrollmentsController < ::ApplicationController
    include PluginGated
    plugin :leads
    include LeadScoped

    requires_capability "leads:write", only: [:create, :update]

    def create
      sequence = Sequence.find(params.require(:enrollment)[:sequence_id])

      if (refusal = @lead.enrollment_refusal(sequence))
        redirect_to lead_path(@lead), alert: refusal
      else
        @lead.enroll(sequence)
        redirect_to lead_path(@lead), notice: "Enrolled in #{sequence.name}"
      end
    end

    # Only stopping, so far.
    def update
      enrollment = @lead.enrollments.find(params[:id])
      enrollment.stop(reason: "stopped by hand", user: Current.user)
      redirect_to lead_path(@lead), notice: "Stopped #{enrollment.sequence.name}"
    end
  end
end
