module Leads
  # A form's key: the part of the capture address (/leads/capture/:token) that lets a website send
  # leads in. It can only add leads, so it isn't a password, but each form gets its own so one can
  # be cut off (deleted) without touching the others. Counts what it sent and when it last did.
  class CaptureKey < ApplicationRecord
    self.table_name = "leads_capture_keys"

    has_secure_token :token, length: 24

    normalizes :name, with: ->(name) { name.to_s.squish }
    validates :name, presence: true, length: { maximum: 60 }
    validates :token, format: { with: /\A[A-Za-z0-9_-]{16,64}\z/ }, allow_nil: true

    scope :ordered, -> { order(:name, :id) }

    def used! = update_columns(leads_count: leads_count + 1, last_used_at: Time.current)
  end
end
