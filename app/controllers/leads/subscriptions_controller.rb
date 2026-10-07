# frozen_string_literal: true

# Putting an unsubscribed lead back on the emails, when it asked to be.
module Leads
  class SubscriptionsController < ::ApplicationController
    include PluginGated
    plugin :leads
    include LeadScoped

    requires_capability "leads:write", only: :create

    def create
      @lead.resubscribe
      redirect_to lead_path(@lead), notice: "#{@lead.display_name} gets emails again"
    end
  end
end
