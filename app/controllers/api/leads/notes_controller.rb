# frozen_string_literal: true

# POST /api/leads/:lead_id/notes {note: {body:}} — a note on the lead's timeline.
module Api
  module Leads
    class NotesController < ::Api::BaseController
      include PluginGated
      plugin :leads
      include LeadScoped

      enforce_authorization
      requires_capability "leads:write", only: :create

      def create
        @activity = @lead.add_note(params.require(:note)[:body])
        render "api/leads/activities/show", status: :created
      rescue ArgumentError => e
        render json: {error: "invalid", message: e.message}, status: :unprocessable_entity
      end
    end
  end
end
