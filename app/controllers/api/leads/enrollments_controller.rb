# frozen_string_literal: true

# POST /api/leads/:lead_id/enrollments {enrollment: {sequence_id:}} — the lead
# into a sequence, or 422 saying why it can't be.
module Api
  module Leads
    class EnrollmentsController < ::Api::BaseController
      include PluginGated
      plugin :leads
      include LeadScoped

      enforce_authorization
      requires_capability "leads:write", only: :create

      def create
        sequence = ::Leads::Sequence.find(params.require(:enrollment)[:sequence_id])

        if (refusal = @lead.enrollment_refusal(sequence))
          render json: {error: "not_enrollable", message: refusal}, status: :unprocessable_entity
        else
          @enrollment = @lead.enroll(sequence)
          render "api/leads/enrollments/show", status: :created
        end
      end
    end
  end
end
