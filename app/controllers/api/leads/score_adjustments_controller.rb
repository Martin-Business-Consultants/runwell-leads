# frozen_string_literal: true

# POST /api/leads/:lead_id/score_adjustments {score_adjustment: {points:, reason:}}
# — answers with the lead, its score changed.
module Api
  module Leads
    class ScoreAdjustmentsController < ::Api::BaseController
      include PluginGated
      plugin :leads
      include LeadScoped

      enforce_authorization
      requires_capability "leads:write", only: :create

      def create
        adjustment = params.require(:score_adjustment)
        @lead.adjust_score(adjustment[:points], reason: adjustment[:reason])
        @lead.reload
        render "api/leads/leads/show", status: :created
      rescue ArgumentError => e
        render json: {error: "invalid", message: e.message}, status: :unprocessable_entity
      end
    end
  end
end
