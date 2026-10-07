# frozen_string_literal: true

module Leads
  # A nurture sequence: emails (Leads::Step) sent one after another, each a
  # delay after the enrollment or the step before. Leads join it by hand or
  # through its trigger — a form submitted, a stage reached — and it sends
  # only while it's active.
  class Sequence < ApplicationRecord
    include Eventable
    include Stepped
    include Testable

    def self.eventable_prefix = "lead_sequence"

    TRIGGERS = {"manual" => "Only by hand", "form" => "When a form is submitted", "stage" => "When a lead reaches a stage"}.freeze

    has_many :enrollments, class_name: "Leads::Enrollment", dependent: :delete_all

    validates :name, presence: true, length: {maximum: 120}
    validates :trigger, inclusion: {in: TRIGGERS.keys}
    validates :trigger_form_id, presence: {message: "must be chosen for a form trigger"}, if: -> { trigger == "form" }
    validates :trigger_stage, inclusion: {in: Leads::Lead::STAGES, message: "must be chosen for a stage trigger"}, if: -> { trigger == "stage" }

    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:name, :id) }
    scope :triggered_by_form, ->(form) { where(trigger: "form", trigger_form_id: form.id) }
    scope :triggered_by_stage, ->(stage) { where(trigger: "stage", trigger_stage: stage.to_s) }

    before_validation :forget_unused_trigger

    def trigger_form
      Form.with_discarded.find_by(id: trigger_form_id) if trigger_form_id && defined?(::Form)
    end

    def trigger_label
      case trigger
      when "form" then "Form: #{trigger_form&.title || "deleted form"}"
      when "stage" then "Stage: #{trigger_stage.to_s.humanize}"
      else "Manual"
      end
    end

    # Recorded first, so the audit row names the sequence as it was. Its
    # enrollments go with it; the emails it sent stay on the leads' timelines.
    def remove
      track_event(:deleted, name: name)
      destroy!
    end

    private

    def forget_unused_trigger
      self.trigger_form_id = nil unless trigger == "form"
      self.trigger_stage = nil unless trigger == "stage"
    end
  end
end
