module Leads
  # The forms that send leads in, in Settings › Plugins › Leads: each a name and a key, the key part
  # of the address the website posts to. Deleting one cuts that form off at once. Keys to send data
  # in are made and removed in the browser only.
  class CaptureKeysController < ApplicationController
    allow_staff
    require_permission :manage_settings
    browser_only :create, :destroy, reason: "A key that lets a website send leads in, made and removed by a person in Settings."

    def create
      key = CaptureKey.new(params.expect(capture_key: [ :name ]))
      if key.save
        redirect_to leads_settings_path(anchor: "forms"), notice: "#{key.name} can send leads in: copy its address below into the form."
      else
        redirect_to leads_settings_path(anchor: "forms"), alert: key.errors.full_messages.to_sentence
      end
    end

    def destroy
      key = CaptureKey.find(params[:id])
      key.destroy!
      redirect_to leads_settings_path(anchor: "forms"), notice: "#{key.name} can no longer send leads in."
    end
  end
end
