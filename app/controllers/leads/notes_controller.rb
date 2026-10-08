module Leads
  class NotesController < ApplicationController
    allow_staff
    agent_tool :add_lead_note, on: :create, title: "Add a note to a lead",
      description: "What was said or decided, on the lead's timeline.", params: { note: { body: "text!" } }

    before_action :set_lead

    def create
      @lead.add_note(params.expect(note: :body)[:body])
      redirect_to lead_path(@lead), notice: "Note added."
    rescue ArgumentError => e
      redirect_to lead_path(@lead), alert: e.message
    end
  end
end
