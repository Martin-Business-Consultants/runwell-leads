module Leads
  # The morning email (Setting#digest_hour, in the install's zone): each person with open leads
  # hears what's due today or late, and which of theirs are going cold; whoever's told about new
  # leads also hears which open ones nobody has. Someone with nothing to do gets nothing. Planned
  # each night for that morning (Runwell::Plugins.nightly), and sent now for one person on asking.
  class DigestJob < ApplicationJob
    queue_as :default

    # Tonight's run: this morning's email at its hour, unless it's off or the hour has gone.
    def self.schedule
      return unless Runwell::Plugins.enabled?(:leads)
      return unless (hour = Setting.current.digest_hour)

      at = Time.current.change(hour: hour, min: 0)
      set(wait_until: at).perform_later(Date.current.iso8601) if at.future?
    end

    def perform(date = nil, only_user_id = nil)
      return unless Runwell::Plugins.enabled?(:leads)
      return if date && date != Date.current.iso8601 # a day late (a queue that was down): skip it

      today = Date.current
      people = User.where(id: Lead.open.where.not(owner_id: nil).select(:owner_id)).to_a
      watchers = Setting.current.notified_people
      unassigned = Lead.open.unassigned.newest.limit(20).to_a
      people |= watchers if unassigned.any?
      people = people.select { it.id == only_user_id.to_i } if only_user_id

      people.select { it.staff? && !it.agent? && it.active? }.each do |person|
        mine = Lead.open.owned_by(person)
        due = Step.open.where(lead_id: mine.select(:id)).where(due_on: ..today).includes(:lead).in_order.to_a
        cold = mine.going_cold.where.not(id: due.map(&:lead_id)).order(:last_activity_at).limit(15).to_a
        nobody = watchers.include?(person) ? unassigned : []
        next if due.empty? && cold.empty? && nobody.empty? && !only_user_id

        Mailer.with(user: person, due: due, cold: cold, nobody: nobody).digest.deliver_later
      end
    end
  end
end
