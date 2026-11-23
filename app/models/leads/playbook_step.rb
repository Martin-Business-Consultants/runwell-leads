module Leads
  # One step of a stage's plan (Settings › Plugins › Leads): when a lead arrives at the stage it
  # gets this step, due days_after days later, starting from an email template if one is named.
  # Changing the plan changes what leads get from then on, not the steps they already have.
  class PlaybookStep < ApplicationRecord
    self.table_name = "leads_playbook_steps"

    belongs_to :stage, class_name: "Leads::Stage"
    belongs_to :template, class_name: "Leads::Template", optional: true

    normalizes :title, with: ->(title) { title.to_s.squish }
    validates :title, presence: true, length: { maximum: 200 }
    validates :days_after, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 365 }

    scope :ordered, -> { order(:days_after, :position, :id) }

    before_create { self.position = (stage.playbook_steps.maximum(:position) || -1) + 1 }

    def when_label = days_after.zero? ? "the same day" : "#{days_after} #{days_after == 1 ? "day" : "days"} later"
  end
end
