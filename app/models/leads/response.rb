module Leads
  # Replies drafted for one lead by the AI plugin (Runwell AI): an email, a text message and a
  # call plan, written from what the lead sent and its timeline, in the team's style (its
  # templates), for someone to check and send themselves. Made in a job (Drafting); the AI plugin's
  # monthly budget covers it, and nothing is drafted while AI is off or the budget is spent.
  class Response < ApplicationRecord
    include Drafting

    STATES = %w[working ready failed].freeze

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :user, class_name: "::User", optional: true

    validates :state, inclusion: { in: STATES }

    scope :latest_first, -> { order(created_at: :desc, id: :desc) }

    def working? = state == "working" && created_at > 3.minutes.ago
    def stuck? = state == "working" && !working?
    def ready? = state == "ready"
    def failed? = state == "failed"

    def email_subject = payload.dig("email", "subject").to_s
    def email_body = payload.dig("email", "body").to_s
    def text_message = payload["text"].to_s
    def call = payload["call"].to_h
    def summary = payload["summary"].to_s
    def next_step = payload["next_step"].to_s
  end
end
