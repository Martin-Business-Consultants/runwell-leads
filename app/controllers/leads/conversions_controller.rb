module Leads
  class ConversionsController < ApplicationController
    allow_staff
    agent_tool :convert_lead_to_client, on: :create, title: "Make a lead a client",
      description: "Makes the client (named for the lead's company, else the lead) with the lead as its contact, or uses the client and contact that already have that name and email. The lead becomes a customer and leaves its sequences.",
      next_tools: %i[show_client create_engagement]

    before_action :set_lead

    def create
      client = @lead.convert_to_client!
      redirect_to main_app.client_path(client), notice: "#{client.name} is a #{term_for_client}, from #{@lead.display_name}."
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      redirect_to lead_path(@lead), alert: e.message
    end

    private
      def term_for_client = Setting.current.term(:client).downcase
  end
end
