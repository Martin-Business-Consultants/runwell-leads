# frozen_string_literal: true

# A lead's place in email sequences (Leads::Enrollment). Someone enrolls it
# by hand, or a sequence's trigger does: a form submitted, a stage reached,
# or the per-form choice in Settings › Leads. A lead that has unsubscribed,
# become a customer or been lost is in none.
module Leads::Lead::Enrollable
  extend ActiveSupport::Concern

  included do
    has_many :enrollments, class_name: "Leads::Enrollment", dependent: :delete_all
  end

  # Whether the plugin may email the lead at all.
  def sendable? = !unsubscribed? && !finished?

  # Why the lead can't be enrolled in `sequence` now, or nil when it can.
  def enrollment_refusal(sequence)
    if unsubscribed? then "#{display_name} has unsubscribed."
    elsif finished? then "#{display_name} is #{stage == "lost" ? "lost" : "a customer"}."
    elsif sequence.steps.empty? then "“#{sequence.name}” has no steps yet."
    elsif enrollments.active.exists?(sequence: sequence) then "#{display_name} is already in “#{sequence.name}”."
    end
  end

  # Starts the sequence from its first step, or returns nil when it can't
  # (enrollment_refusal). A new lead is being nurtured from now on.
  def enroll(sequence, user: Current.user)
    return nil if enrollment_refusal(sequence)

    enrollment = enrollments.create!(sequence: sequence, next_send_at: sequence.steps.first.send_after(Time.current))
    record_activity(:enrolled, summary: "Enrolled in #{sequence.name}", data: {sequence_id: sequence.id}, user: user)
    track_event(:enrolled, sequence: sequence.name) if user
    change_stage("nurturing", user: user, audit: false) if stage == "new"
    enrollment
  end

  def stop_enrollments(reason:)
    enrollments.active.includes(:sequence).each { it.stop(reason: reason) }
  end

  # The active sequences a trigger names, that this lead has never been in
  # (a trigger doesn't send a sequence twice).
  def enroll_in_triggered(sequences)
    sequences.each do |sequence|
      next if enrollments.exists?(sequence: sequence)

      enroll(sequence, user: nil)
    end
  end

  private

  def enroll_in_sequences_for_stage
    enroll_in_triggered(Leads::Sequence.active.triggered_by_stage(stage))
  end
end
