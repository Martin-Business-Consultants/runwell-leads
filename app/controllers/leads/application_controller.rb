module Leads
  # The plugin's staff pages use the core's layout, and vanish while it's switched off. A move a
  # lead's state refuses (Lead::Refused) goes back where it came from, saying why.
  class ApplicationController < ::ApplicationController
    layout "application"

    before_action { head :not_found unless Runwell::Plugins.enabled?(:leads) }
    rescue_from Lead::Refused, with: :refused

    private
      def set_lead = @lead = Lead.find(params[:lead_id] || params[:id])

      def refused(error)
        redirect_back fallback_location: (@lead ? lead_path(@lead) : leads_path), alert: error.message
      end

      # owner_id as an id, "me", or a name ("Amir"); blank or "nobody" for no one.
      def owner_from(value)
        return if value.blank? || value.to_s == "nobody"
        return Current.user.person if value.to_s == "me"
        return User.find_by(id: value) if value.to_s.match?(/\A\d+\z/)

        User.where(role: User::Role::ROLES, agent_owner_id: nil).active.find_by("LOWER(name) LIKE ?", "#{User.sanitize_sql_like(value.to_s.downcase)}%")
      end
  end
end
