module Leads
  class SubscriptionsController < ApplicationController
    allow_staff
    agent_tool :resubscribe_lead, on: :create, title: "Subscribe a lead to emails again",
      description: "Only when the lead asked for it: it unsubscribed itself.", confirm: "The lead can be emailed by sequences again."

    before_action :set_lead

    def create
      @lead.resubscribe
      redirect_to lead_path(@lead), notice: "#{@lead.display_name} can get emails again."
    end
  end
end
