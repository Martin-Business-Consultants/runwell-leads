module Leads
  # Settings › Plugins › Leads, for whoever manages settings: who's told when a lead comes in, the
  # morning email and when a lead goes cold, the stages an open lead moves through and each one's
  # plan, the email templates, and the forms that send leads in (their keys and address).
  class SettingsController < ApplicationController
    allow_staff
    require_permission :manage_settings
    agent_tool :show_leads_settings, on: :show, title: "Show the leads' settings",
      description: "Who's emailed when a lead comes in (nobody picked: every owner and manager), the morning email's hour and when a lead goes cold, " \
        "the stages in order with how many open leads each holds and each one's plan (the steps a lead gets on arriving), the email templates, and how many forms send leads in."
    agent_tool :update_leads_settings, on: :update, title: "Change who hears about new leads, the morning email, or when leads go cold",
      description: "notify_user_ids: the people emailed when a lead comes in or comes back; empty for every owner and manager. " \
        "digest_hour: the hour (#{Setting::DIGEST_HOURS.first} to #{Setting::DIGEST_HOURS.last}, the install's time) each person is emailed their follow-ups; blank for none. " \
        "cold_after_days: days without anyone in touch before an open lead is going cold; blank for never. Only what's given changes.",
      params: { setting: { notify_user_ids: "integer[]", digest_hour: "integer", cold_after_days: "integer" } }, next_tools: %i[show_leads_settings]

    def show
      @setting = Setting.current
      @stages = Stage.ordered.to_a
      @open_counts = Lead.open.group(:stage_id).count
      @used_stage_ids = Lead.distinct.pluck(:stage_id).compact
      @keys = CaptureKey.ordered.to_a
      @templates = Template.ordered.to_a
      @plans = PlaybookStep.includes(:template).ordered.group_by(&:stage_id)
      @page_title = "Leads"
    end

    def update
      setting = Setting.current
      changes = params.fetch(:setting, {}).permit(:digest_hour, :cold_after_days, notify_user_ids: []).to_h
      return redirect_to(leads_settings_path, alert: setting.errors.full_messages.to_sentence) unless setting.update(changes)

      redirect_to leads_settings_path, notice: settings_notice(setting, changes)
    end

    private
      def settings_notice(setting, changes)
        if changes.key?("notify_user_ids")
          "New leads go to #{setting.notify_user_ids.any? ? setting.notified_people.map(&:display_name).to_sentence : "every owner and manager"}."
        elsif changes.key?("digest_hour")
          setting.digest_hour ? "Follow-ups are emailed at #{setting.digest_label} each morning." : "No morning email."
        else
          setting.cold_after_days ? "A lead goes cold after #{setting.cold_after_days} days without anyone in touch." : "Leads never go cold."
        end
    end
  end
end
