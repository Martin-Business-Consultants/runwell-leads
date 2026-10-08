module Leads
  class SettingsController < ApplicationController
    require_permission :manage_settings
    agent_tool :show_leads_settings, on: :show, title: "Show the Leads settings",
      description: "Points per thing a lead does, the qualifying score, and how a website's form sends leads in."
    agent_tool :update_leads_settings, on: :update, title: "Change the Leads settings",
      description: "points: capture, email_open, email_click, note. threshold: the score that qualifies a lead. thanks_url: where a form without its own redirect_to sends people.",
      params: { settings: { points: { capture: "integer", email_open: "integer", email_click: "integer", note: "integer" }, threshold: "integer", thanks_url: "string", ai_drafts: "boolean" } }

    before_action { @settings = Leads::Settings.current }

    def show
      @sources = Lead.where(source: "website").where.not(source_label: nil).distinct.pluck(:source_label).sort
    end

    def update
      if @settings.revise(params.expect(settings: [ :threshold, :thanks_url, :ai_drafts, points: Leads::Settings::POINTS.keys ]))
        redirect_to leads_settings_path, notice: "Saved."
      else
        redirect_to leads_settings_path, alert: @settings.errors.full_messages.to_sentence
      end
    end
  end
end
