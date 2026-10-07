# frozen_string_literal: true

# A note on a lead's timeline.
module Leads
  class NotesController < ::ApplicationController
    include PluginGated
    plugin :leads
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      @lead.add_note(params.require(:note).permit(:body)[:body])
      redirect_to lead_path(@lead, anchor: "timeline"), notice: "Note added"
    rescue ArgumentError => e
      redirect_to lead_path(@lead, anchor: "timeline"), alert: e.message
    end
  end
end
