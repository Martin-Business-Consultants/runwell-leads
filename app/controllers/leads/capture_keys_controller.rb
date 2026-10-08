module Leads
  class CaptureKeysController < ApplicationController
    require_permission :manage_settings
    agent_tool :renew_leads_capture_key, on: :create, title: "Renew the Leads capture key",
      description: "Forms still posting the old key stop making leads until they're given the new one.",
      confirm: "Every form on your website that sends leads has to be updated with the new key."

    def create
      Leads::Settings.current.renew_capture_key!
      redirect_to leads_settings_path, notice: "New key made. Put it in your website’s forms."
    end
  end
end
