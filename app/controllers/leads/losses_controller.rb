module Leads
  # Losing a lead, with why (Lead::LOST_REASONS) and an optional line. It's kept, closed, and can
  # be reopened; if they send the form again it reopens by itself.
  class LossesController < ApplicationController
    allow_staff
    agent_tool :lose_lead, on: :create, title: "Lose a lead",
      description: "Closes an open lead as lost. reason: #{Lead::LOST_REASONS.map { |key, label| "#{key} (#{label})" }.join(", ")}. note: a line saying more, kept in its history. " \
        "Spam for junk. It reopens by itself if they send the form again.",
      params: { loss: { reason: Lead::LOST_REASONS.keys, note: "string" } }

    before_action :set_lead

    def create
      loss = params.expect(loss: %i[reason note])
      @lead.lose!(reason: loss[:reason], note: loss[:note])
      redirect_back fallback_location: lead_path(@lead), notice: "#{@lead.display_name} lost: #{@lead.lost_reason_label.downcase}."
    end
  end
end
