module Leads
  # The plugin's settings, one row: who's emailed when a lead comes in (nobody picked means every
  # owner and manager, so a new install never drops a lead on the floor), the hour of the morning
  # email with each person's follow-ups (nil: none), and how many days without anyone in touch make
  # an open lead go cold (nil: never).
  class Setting < ApplicationRecord
    self.table_name = "leads_settings"

    DIGEST_HOURS = (5..11).to_a.freeze

    validates :digest_hour, inclusion: { in: DIGEST_HOURS }, allow_nil: true
    validates :cold_after_days, numericality: { only_integer: true, in: 1..90 }, allow_nil: true

    after_commit { Leads::PerRequest.cold_read = false }

    def digest_hour=(value)
      super(value.presence)
    end

    def cold_after_days=(value)
      super(value.presence)
    end

    def digest_label = digest_hour ? Time.zone.now.change(hour: digest_hour).strftime("%-l%P") : "off"

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
