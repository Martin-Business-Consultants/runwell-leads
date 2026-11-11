module Leads
  # Taking an unassigned lead: it's yours. One someone else has stays theirs (change its owner to
  # hand it over instead).
  class ClaimsController < ApplicationController
    allow_staff
    agent_tool :claim_lead, on: :create, title: "Claim a lead",
      description: "Makes an open, unassigned lead yours (your person's, for an agent). One someone else has is refused: hand it over with update_lead's owner_id.",
      next_tools: %i[show_lead log_lead_activity]

    before_action :set_lead

    def create
      @lead.claim!(Current.user.person)
      redirect_back fallback_location: lead_path(@lead), notice: "#{@lead.display_name} is yours."
    end
  end
end
