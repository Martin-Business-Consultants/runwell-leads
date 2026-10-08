# Where a lead is: new, being nurtured, qualified, a customer, or lost. A change of stage goes on
# the timeline; a customer or a lost lead leaves its sequences, and reaching a stage enrolls the
# lead in the sequences that start there.
module Leads::Lead::Staged
  extend ActiveSupport::Concern

  STAGES = %w[new nurturing qualified customer lost].freeze
  # Stages a lead is done being nurtured in.
  FINISHED_STAGES = %w[customer lost].freeze

  included do
    scope :in_stage, ->(stage) { where(stage: stage) }
    scope :open, -> { where.not(stage: FINISHED_STAGES) }
  end

  class_methods do
    # The list's stage filter, each choice with how many it holds.
    def filter_options
      counts = group(:stage).count
      [ [ "Open (#{counts.except(*FINISHED_STAGES).values.sum})", "open" ] ] +
        STAGES.map { [ "#{it.humanize} (#{counts.fetch(it, 0)})", it ] } +
        [ [ "All (#{counts.values.sum})", "all" ] ]
    end
  end

  def finished? = FINISHED_STAGES.include?(stage)

  # Returns whether the stage changed.
  def change_stage(to, user: Current.user)
    to = to.to_s
    raise ArgumentError, "Unknown stage #{to.inspect}" unless STAGES.include?(to)
    return false if to == stage

    from = stage
    update!(stage: to)
    record_activity(:stage_changed, summary: "#{from.humanize} → #{to.humanize}", data: { from: from, to: to }, user: user)
    stop_enrollments(reason: to) if finished?
    enroll_in_sequences_for_stage
    true
  end

  # An edit from the lead's page or an agent: its details, and its stage through change_stage.
  # Returns whether it saved; errors are on the lead.
  def revise(attributes, user: Current.user)
    attributes = attributes.to_h.stringify_keys
    stage = attributes.delete("stage").presence
    if stage && STAGES.exclude?(stage)
      errors.add(:stage, "is not one of #{STAGES.join(", ")}")
      return false
    end

    transaction do
      update!(attributes)
      change_stage(stage, user: user) if stage
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end
end
