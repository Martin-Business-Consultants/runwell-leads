# frozen_string_literal: true

# GET /api/leads/sequences — the email sequences with their steps, for
# enrolling a lead (POST /api/leads/:lead_id/enrollments).
module Api
  module Leads
    class SequencesController < ::Api::BaseController
      include PluginGated
      plugin :leads

      enforce_authorization
      requires_capability "sequences:read", only: :index

      def index
        @sequences = ::Leads::Sequence.ordered.includes(:steps)
      end
    end
  end
end
