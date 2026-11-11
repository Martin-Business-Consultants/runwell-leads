module Leads
  # One line of a lead's history: something a person logged (a call, an email, a meeting, a note,
  # LOGGED), or a change recorded as it happened (it came in, came in again, changed owner, stage or
  # next step, was won, lost or reopened). Newest first on the lead's page and in its JSON.
  class Activity < ApplicationRecord
    self.table_name = "leads_activities"

    LOGGED = { "call" => "Call", "email" => "Email", "meeting" => "Meeting", "note" => "Note" }.freeze

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :user, optional: true

    validates :kind, presence: true
    validates :body, presence: { message: "needs a few words" }, if: :logged?

    def logged? = LOGGED.key?(kind)
    def removable_by?(person) = logged? && (user&.person == person.person || person.can?(:delete_records))

    # What happened, in a sentence without its author ("moved it to Call held").
    def summary(stages: nil, people: nil)
      case kind
      when "created" then data["source"] ? "added it, from #{data["source"]}" : "added it"
      when "submitted" then "sent the form again#{" (#{data["source"]})" if data["source"]}"
      when "owner" then data["to"].nil? ? "left it unassigned" : data["to"] == user&.person&.id ? "took it" : "gave it to #{person_name(data["to"], people)}"
      when "stage" then "moved it to #{stage_name(data["to"], stages)}"
      when "next_step" then next_step_text
      when "value" then data["cents"] ? "valued it at #{ActiveSupport::NumberHelper.number_to_currency(data["cents"].to_i / 100.0, precision: 0)}" : "cleared its value"
      when "won" then "won it#{" as #{data["client"]}" if data["client"]}"
      when "lost" then "lost it: #{Lead::LOST_REASONS[data["reason"]] || "no reason"}"
      when "reopened" then "reopened it"
      else LOGGED[kind] ? "logged #{LOGGED[kind].downcase == "email" ? "an email" : "a #{LOGGED[kind].downcase}"}" : kind.humanize.downcase
      end
    end

    def author = user&.display_name || (kind.in?(%w[created submitted reopened]) ? "The website" : "Someone")

    private
      def next_step_text
        return "cleared the next step" if data["step"].blank? && data["on"].blank?

        date = Date.parse(data["on"]).strftime("%b %-d") if data["on"].present?
        [ "set the next step:", data["step"].presence || "something", ("by #{date}" if date) ].compact.join(" ")
      rescue Date::Error
        "set the next step: #{data["step"]}"
      end

      def stage_name(id, stages) = (stages ? stages[id] : Stage.find_by(id: id))&.then { it.is_a?(String) ? it : it.name } || "a stage since removed"
      def person_name(id, people) = (people ? people[id] : User.find_by(id: id))&.then { it.is_a?(String) ? it : it.display_name } || "someone"
  end
end
