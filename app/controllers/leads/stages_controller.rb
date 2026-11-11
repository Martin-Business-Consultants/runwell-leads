module Leads
  # The stages an open lead moves through, in Settings › Plugins › Leads: added at the end, renamed,
  # moved up or down, and deleted while no lead is in one.
  class StagesController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :create_lead_stage, on: :create, title: "Add a lead stage",
      description: "A new step open leads move through, added last (Won and Lost aren't stages: they close a lead).",
      params: { stage: { name: "string!" } }, next_tools: %i[show_leads_settings]
    agent_tool :update_lead_stage, on: :update, title: "Rename or move a lead stage",
      description: "name: its new name. move: up or down one place. The first stage is where new leads land.",
      params: { stage: { name: "string" }, move: %w[up down] }, next_tools: %i[show_leads_settings]
    agent_tool :delete_lead_stage, on: :destroy, title: "Delete a lead stage",
      description: "Only one no lead is in (move them first), and never the last."

    def create
      stage = Stage.new(params.expect(stage: [ :name ]))
      if stage.save
        redirect_to leads_settings_path, notice: "#{stage.name} added, last."
      else
        redirect_to leads_settings_path, alert: stage.errors.full_messages.to_sentence
      end
    end

    def update
      stage = Stage.find(params[:id])
      if params[:move].present?
        stage.move!(params[:move])
        return redirect_to(leads_settings_path, notice: "#{stage.name} moved #{params[:move]}.")
      end

      if stage.update(params.expect(stage: [ :name ]))
        redirect_to leads_settings_path, notice: "Renamed #{stage.name}."
      else
        redirect_to leads_settings_path, alert: stage.errors.full_messages.to_sentence
      end
    end

    def destroy
      stage = Stage.find(params[:id])
      return redirect_to(leads_settings_path, alert: stage.refusal_to_delete) unless stage.deletable?

      stage.destroy!
      redirect_to leads_settings_path, notice: "#{stage.name} deleted."
    end
  end
end
