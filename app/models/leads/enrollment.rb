# frozen_string_literal: true

module Leads
  # A lead in a sequence: which step goes next and when. Active until every
  # step has gone (completed) or it's stopped — by hand, or because the lead
  # unsubscribed, became a customer or was lost. Delivering (Deliverable)
  # sends the due step and schedules the next.
  class Enrollment < ApplicationRecord
    include Eventable
    include Deliverable

    def self.eventable_prefix = "lead_enrollment"

    STATUSES = %w[active completed stopped].freeze

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :sequence, class_name: "Leads::Sequence"
    has_many :messages, class_name: "Leads::Message", dependent: :nullify

    validates :status, inclusion: {in: STATUSES}

    scope :active, -> { where(status: "active") }
    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    def active? = status == "active"

    # The step that goes next, or nil when none is left.
    def next_step = sequence.steps[current_step]

    def progress_label = "#{[current_step, sequence.steps.size].min} of #{sequence.steps.size} sent"

    def stop(reason: "stopped by hand", user: nil)
      return false unless active?

      update!(status: "stopped", finished_at: Time.current, next_send_at: nil, stop_reason: reason.to_s)
      lead.record_activity(:enrollment_stopped, summary: "Left #{sequence.name} (#{reason.to_s.humanize(capitalize: false)})",
        data: {sequence_id: sequence_id, reason: reason.to_s}, user: user)
      track_event(:stopped, sequence: sequence.name, lead: lead.email) if user
      true
    end

    def complete
      update!(status: "completed", finished_at: Time.current, next_send_at: nil)
      lead.record_activity(:enrollment_completed, summary: "Finished #{sequence.name}", data: {sequence_id: sequence_id}, user: nil)
    end
  end
end
