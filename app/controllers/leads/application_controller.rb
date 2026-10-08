module Leads
  # The plugin's pages use the core's layout, and vanish while it's switched off.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:leads) }

    private
      def set_lead = @lead = Lead.find(params[:lead_id] || params[:id])
  end
end
