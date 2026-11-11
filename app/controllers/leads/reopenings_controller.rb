module Leads
  # Opening a lost lead again, at the stage it was at. A won lead stays won: it's a client now.
  class ReopeningsController < ApplicationController
    allow_staff
    agent_tool :reopen_lead, on: :create, title: "Reopen a lost lead",
      description: "Puts a lost lead back in the pipeline at the stage it was at. A won lead can't be reopened: it's a client.",
      next_tools: %i[show_lead update_lead]

    before_action :set_lead

    def create
      @lead.reopen!
      redirect_back fallback_location: lead_path(@lead), notice: "#{@lead.display_name} is open again, at #{@lead.stage&.name}."
    end
  end
end
