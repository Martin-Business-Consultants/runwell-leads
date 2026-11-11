module Leads
  # The plugin's settings, one row: who's emailed when a lead comes in. Nobody picked means every
  # owner and manager, so a new install never drops a lead on the floor.
  class Setting < ApplicationRecord
    self.table_name = "leads_settings"

    def self.current = first || create!

    def notify_user_ids=(ids)
      super(Array(ids).compact_blank.map(&:to_i).uniq)
    end

    # The active people on the team who hear about a new lead.
    def notified_people
      picked = User.where(id: notify_user_ids).to_a.select { listener?(it) }
      picked.any? ? picked : User.where(role: %w[owner manager]).to_a.select { listener?(it) }
    end

    private
      def listener?(user) = user.staff? && !user.agent? && user.active?
  end
end
