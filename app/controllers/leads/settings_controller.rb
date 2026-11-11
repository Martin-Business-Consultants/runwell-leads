module Leads
  # Settings › Plugins › Leads, for whoever manages settings: who's told when a lead comes in, the
  # stages an open lead moves through, and the forms that send leads in (their keys and address).
  class SettingsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :show_leads_settings, on: :show, title: "Show the leads' settings",
      description: "Who's emailed when a lead comes in (nobody picked: every owner and manager), the stages in order with how many open leads each holds, and how many forms send leads in."
    agent_tool :update_leads_settings, on: :update, title: "Change who hears about new leads",
      description: "notify_user_ids: the people emailed when a lead comes in or comes back; empty for every owner and manager.",
      params: { setting: { notify_user_ids: "integer[]" } }, next_tools: %i[show_leads_settings]

    def show
      @setting = Setting.current
      @stages = Stage.ordered.to_a
      @open_counts = Lead.open.group(:stage_id).count
      @used_stage_ids = Lead.distinct.pluck(:stage_id).compact
      @keys = CaptureKey.ordered.to_a
      @page_title = "Leads"
    end

    def update
      setting = Setting.current
      setting.update!(notify_user_ids: params.dig(:setting, :notify_user_ids) || [])
      people = setting.notify_user_ids.any? ? setting.notified_people.map(&:display_name).to_sentence : "every owner and manager"
      redirect_to leads_settings_path, notice: "New leads go to #{people}."
    end
  end
end
