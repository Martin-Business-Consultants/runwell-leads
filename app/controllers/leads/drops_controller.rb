module Leads
  # A card dropped on another stage's column of the board (the core's drag-and-drop controller):
  # the lead moves there and the board is drawn again, keeping the page's filters.
  class DropsController < ApplicationController
    allow_staff
    agent_exempt :create, reason: "The board's drag and drop; agents move a lead with update_lead's stage_id."

    def create
      lead = Lead.find(params[:id])
      stage = Stage.find(params[:stage_id])
      lead.move_to!(stage)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: [ turbo_stream.refresh(request_id: nil), turbo_stream_flash(notice: "#{lead.display_name} is at #{stage.name}.") ] }
        format.html { redirect_back fallback_location: leads_path(view: "board"), notice: "#{lead.display_name} is at #{stage.name}." }
      end
    end
  end
end
