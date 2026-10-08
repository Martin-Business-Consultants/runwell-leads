module Leads
  # Settings › Leads, one row: the points each thing a lead does is worth, the score that qualifies
  # it, the key a website's form posts with, and where a form without its own redirect sends
  # people after.
  class Settings < ApplicationRecord
    POINTS = { "capture" => 10, "email_open" => 1, "email_click" => 3, "note" => 0 }.freeze
    POINT_LABELS = { "capture" => "Came in from the website", "email_open" => "Opened an email",
                     "email_click" => "Clicked a link in an email", "note" => "A note added" }.freeze

    validates :threshold, numericality: { only_integer: true, greater_than: 0 }
    validates :thanks_url, format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }, allow_blank: true

    before_validation(on: :create) { self.capture_key ||= self.class.new_key }

    def self.current = first || create!
    def self.new_key = SecureRandom.alphanumeric(24)

    def points_for(event)
      value = points.to_h[event.to_s]
      value.nil? ? POINTS.fetch(event.to_s, 0) : value.to_i
    end

    # What Settings › Leads posts: points by key, threshold, thanks URL.
    def revise(params)
      params = params.to_h.stringify_keys
      update(points: POINTS.keys.index_with { Integer(params.dig("points", it).to_s, exception: false) || points_for(it) },
        threshold: params.fetch("threshold", threshold), thanks_url: params.fetch("thanks_url", thanks_url).to_s.strip.presence)
    end

    # A new key: forms still posting the old one stop making leads.
    def renew_capture_key! = update!(capture_key: self.class.new_key)

    def matches_key?(key) = key.present? && ActiveSupport::SecurityUtils.secure_compare(key.to_s, capture_key)
  end
end
