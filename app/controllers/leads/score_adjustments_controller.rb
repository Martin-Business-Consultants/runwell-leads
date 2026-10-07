# frozen_string_literal: true

# Changing a lead's score by hand, with a reason (Leads::Lead::Scored).
module Leads
  class ScoreAdjustmentsController < ::ApplicationController
    include PluginGated
    plugin :leads
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      adjustment = params.require(:score_adjustment).permit(:points, :reason)
      @lead.adjust_score(adjustment[:points], reason: adjustment[:reason])
      redirect_to lead_path(@lead), notice: "Score is now #{@lead.reload.score}"
    rescue ArgumentError => e
      redirect_to lead_path(@lead), alert: e.message
    end
  end
end
