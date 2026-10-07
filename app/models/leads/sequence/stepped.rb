# frozen_string_literal: true

# A sequence's steps, edited as one list: the editor posts every row in the
# order it shows them (sequence[steps][<key>][…], as the content editor's
# blocks do), and saving keeps the rows that still have an id, adds the new
# ones and removes the rest, numbering them in that order.
module Leads::Sequence::Stepped
  extend ActiveSupport::Concern

  STEP_ATTRIBUTES = %w[delay_amount delay_unit subject body].freeze

  included do
    has_many :steps, -> { order(:position, :id) }, class_name: "Leads::Step", inverse_of: :sequence,
      autosave: true, dependent: :destroy
  end

  # The steps as they'll be saved, without those marked to go.
  def kept_steps = steps.reject(&:marked_for_destruction?)

  # attributes: the sequence's own; rows: an ordered list of step hashes
  # (with "id" for a step that exists). Returns whether it saved.
  def save_with_steps(attributes, rows)
    assign_attributes(attributes)
    assign_steps(rows)
    save
  end

  def assign_steps(rows)
    existing = steps.index_by(&:id)
    kept = rows.each_with_index.map do |row, index|
      row = row.to_h.stringify_keys
      step = existing[row["id"].to_i] || steps.build
      step.assign_attributes(row.slice(*STEP_ATTRIBUTES).merge("position" => index))
      step
    end
    (steps.to_a - kept).each(&:mark_for_destruction)
  end

  class_methods do
    # The editor's rows, keyed opaquely, in the order they were posted.
    def step_rows(raw)
      hash = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
      hash.values.select { it.is_a?(Hash) }
    end
  end
end
