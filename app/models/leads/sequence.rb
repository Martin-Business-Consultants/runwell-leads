module Leads
  # An email sequence: emails (Leads::Step) sent one after another, each a delay after the lead
  # joined or the email before. Leads join by hand or through its trigger (coming in from the
  # website, from one form or any; reaching a stage), and it sends only while it's switched on.
  class Sequence < ApplicationRecord
    include Testable

    TRIGGERS = { "manual" => "Only by hand", "captured" => "When a lead comes in from the website", "stage" => "When a lead reaches a stage" }.freeze

    has_many :steps, -> { order(:position, :id) }, class_name: "Leads::Step", inverse_of: :sequence, dependent: :destroy
    has_many :enrollments, class_name: "Leads::Enrollment", dependent: :delete_all

    normalizes :trigger_source, with: -> { it.strip.presence }

    validates :name, presence: true, length: { maximum: 120 }
    validates :trigger, inclusion: { in: TRIGGERS.keys }
    validates :trigger_stage, inclusion: { in: Leads::Lead::STAGES, message: "must be chosen for a stage trigger" }, if: -> { trigger == "stage" }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name, :id) }
    scope :triggered_by_stage, ->(stage) { where(trigger: "stage", trigger_stage: stage.to_s) }
    # Sequences for every website lead, and those for this form's (by its source, any case).
    scope :triggered_by_capture, ->(source) {
      where(trigger: "captured").where("trigger_source IS NULL OR LOWER(trigger_source) = ?", source.to_s.strip.downcase)
    }

    before_validation :forget_unused_trigger
    after_update_commit -> { Leads::Enrollment.deliver_due_later }, if: -> { saved_change_to_active?(to: true) }

    def trigger_label
      case trigger
      when "captured" then trigger_source ? "From the website: #{trigger_source}" : "From the website"
      when "stage" then "Reaches #{trigger_stage.to_s.humanize.downcase}"
      else "By hand"
      end
    end

    def status_label = active? ? "On" : "Off"

    private
      def forget_unused_trigger
        self.trigger_source = nil unless trigger == "captured"
        self.trigger_stage = nil unless trigger == "stage"
      end
  end
end
