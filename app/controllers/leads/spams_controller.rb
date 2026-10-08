module Leads
  class SpamsController < ApplicationController
    allow_staff
    agent_tool :mark_lead_spam, on: :create, title: "Mark a lead as spam",
      description: "Moves it out of the lists (the Spam filter still shows it) and stops its emails. The same address coming back from a form is ignored."
    agent_tool :unmark_lead_spam, on: :destroy, title: "Mark a lead as not spam", description: "Puts it back as a new lead."

    before_action :set_lead

    def create
      @lead.mark_spam
      redirect_to leads_path, notice: "#{@lead.display_name} marked as spam."
    end

    def destroy
      @lead.unmark_spam
      redirect_to lead_path(@lead), notice: "#{@lead.display_name} is back as a new lead."
    end
  end
end
