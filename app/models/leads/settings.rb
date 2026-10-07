# frozen_string_literal: true

module Leads
  # Settings › Leads, kept in the "leads_settings" Setting: the points each
  # event is worth, the score that qualifies a lead, who sequence emails come
  # from, and per form (by slug) whether its submissions become leads and
  # which sequence a new lead from it joins.
  class Settings
    POINTS = {"submission" => 10, "email_open" => 1, "email_click" => 3, "note" => 0}.freeze
    POINT_LABELS = {"submission" => "Form submission", "email_open" => "Email opened",
                    "email_click" => "Link clicked", "note" => "Note added"}.freeze
    THRESHOLD = 50
    DEFAULT_FROM_NAME = "Leads"

    def self.current = new(Setting.get(Leads::SETTING_KEY))

    # What Settings › Leads posts: points, threshold, sender, and capture
    # rows keyed by form slug ({"contact" => {"enabled" => "1", "sequence_id" => "3"}}).
    def self.update(params)
      params = params.to_h.deep_stringify_keys
      data = {
        "points" => POINTS.keys.index_with { |key| Integer(params.dig("points", key).to_s, exception: false) || POINTS[key] },
        "threshold" => [Integer(params["threshold"].to_s, exception: false) || THRESHOLD, 1].max,
        "from_name" => params["from_name"].to_s.strip,
        "from_email" => params["from_email"].to_s.strip,
        "capture" => params["capture"].to_h.transform_values do |row|
          {"enabled" => row["enabled"].to_s == "1", "sequence_id" => row["sequence_id"].presence&.to_i}
        end
      }
      Setting.set(Leads::SETTING_KEY, data)
      Event.record("settings.leads_updated", fields: data.keys)
      new(data)
    end

    def initialize(data)
      @data = data || {}
    end

    def points_for(event)
      value = @data.dig("points", event.to_s)
      value.nil? ? POINTS.fetch(event.to_s, 0) : value.to_i
    end

    def threshold = (@data["threshold"].presence || THRESHOLD).to_i

    def from_name = @data["from_name"].presence

    def from_email = @data["from_email"].presence

    # This plugin's sender, then the core's (Settings › General), then the
    # Forms plugin's, then the install's.
    def from_header
      general = Setting.get("general")
      forms = Setting.get("forms_settings")
      name = from_name || general["email_from_name"].presence || forms["from_name"].presence || DEFAULT_FROM_NAME
      address = from_email || general["email_from_address"].presence || forms["from_email"].presence || ApplicationMailer.from_address
      %("#{name.delete('"')}" <#{address}>)
    end

    # Forms are captured unless switched off here.
    def capture?(form) = capture_row(form).fetch("enabled", true) != false

    # The active sequence a new lead from this form joins, or nil.
    def sequence_for(form)
      id = capture_row(form)["sequence_id"]
      id && Leads::Sequence.active.find_by(id: id)
    end

    def sequence_id_for(form) = capture_row(form)["sequence_id"]

    private

    def capture_row(form) = @data.dig("capture", form.slug) || {}
  end
end
