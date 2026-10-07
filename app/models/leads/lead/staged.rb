# frozen_string_literal: true

# Where a lead is: new, being nurtured, qualified, a customer, or lost. A
# change of stage goes on the timeline and to webhooks (lead.stage_changed);
# a customer or a lost lead leaves its sequences, and reaching a stage
# enrolls the lead in the active sequences that start there.
module Leads::Lead::Staged
  extend ActiveSupport::Concern

  STAGES = %w[new nurturing qualified customer lost].freeze
  # Stages a lead is done being nurtured in.
  FINISHED_STAGES = %w[customer lost].freeze

  included do
    scope :in_stage, ->(stage) { where(stage: stage) }
  end

  class_methods do
    # One stage for a set of leads (the list's bulk action), one change each
    # so every lead's timeline, webhooks and sequences follow. Returns the
    # leads that changed.
    def change_stage_of(leads, to:)
      changed = leads.select { |lead| lead.change_stage(to) }
      track_event(:bulk_stage_changed, to: to, emails: changed.map(&:email)) if changed.any?
      changed
    end
  end

  def finished? = FINISHED_STAGES.include?(stage)

  # Returns whether the stage changed. audit: false for a change the plugin
  # made itself (a score crossing the threshold), which has no one behind it.
  def change_stage(to, user: Current.user, audit: true)
    to = to.to_s
    raise ArgumentError, "Unknown stage #{to.inspect}" unless STAGES.include?(to)
    return false if to == stage

    from = stage
    update!(stage: to)
    record_activity(:stage_changed, summary: "Stage changed from #{from.humanize} to #{to.humanize}", data: {from: from, to: to}, user: user)
    track_event(:stage_changed, from: from, to: to) if audit
    announce("lead.stage_changed", webhook_payload.merge(previous_stage: from))
    stop_enrollments(reason: to) if finished?
    enroll_in_sequences_for_stage
    true
  end

  # An edit from the lead's page or the API: its details, and its stage
  # through change_stage. Returns whether it saved; errors are on the lead.
  def revise(attributes, user: Current.user)
    attributes = attributes.to_h.stringify_keys
    stage = attributes.delete("stage").presence
    if stage && STAGES.exclude?(stage)
      errors.add(:stage, "is not one of #{STAGES.join(", ")}")
      return false
    end

    transaction do
      assign_attributes(attributes)
      changes = changed
      save!
      track_event(:updated, fields: changes) if changes.any?
      change_stage(stage, user: user) if stage
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
