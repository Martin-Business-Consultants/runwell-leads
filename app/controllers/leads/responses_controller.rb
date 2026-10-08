module Leads
  # A lead's replies drafted by AI, shown in a frame on its Responses tab that reloads itself while
  # the draft is being written.
  class ResponsesController < ApplicationController
    allow_staff
    agent_tool :show_lead_responses, on: :show, title: "Show the replies drafted for a lead",
      description: "The latest AI draft: an email, a text message, a call plan and the best next step. Check it before sending anything."
    agent_tool :draft_lead_responses, on: :create, title: "Draft replies for a lead with AI",
      description: "Asks the AI plugin for a new email, text message and call plan for this lead (it takes a few seconds; read it with show_lead_responses). Needs AI switched on.",
      next_tools: %i[show_lead_responses]

    before_action :set_lead

    def show
      @response = @lead.responses.latest_first.first
      render layout: false unless request.format.json?
    end

    def create
      if Response.available?
        Response.draft_later(@lead, user: Current.user.person)
        redirect_to lead_responses_path(@lead), notice: "Drafting replies for #{@lead.display_name}."
      else
        redirect_to lead_responses_path(@lead), alert: "AI isn’t available: switch on the AI plugin in Settings › Plugins, or its monthly budget is spent."
      end
    end
  end
end
