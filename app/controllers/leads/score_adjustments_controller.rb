module Leads
  class ScoreAdjustmentsController < ApplicationController
    allow_staff
    agent_tool :adjust_lead_score, on: :create, title: "Adjust a lead's score",
      description: "Add (or, negative, take away) points, with the reason. Crossing the threshold in Settings › Leads qualifies a new or nurturing lead.",
      params: { score_adjustment: { points: "integer!", reason: "string" } }

    before_action :set_lead

    def create
      adjustment = params.expect(score_adjustment: %i[points reason])
      @lead.adjust_score(adjustment[:points], reason: adjustment[:reason])
      redirect_to lead_path(@lead), notice: "#{@lead.display_name}’s score is #{@lead.reload.score}."
    rescue ArgumentError => e
      redirect_to lead_path(@lead), alert: e.message
    end
  end
end
