# frozen_string_literal: true

module Leads
  # One thing on a lead's timeline: a submission, an email sent, opened or
  # clicked, a change of stage or score, a note, a task, an enrollment. Made
  # by the lead's verbs (Lead#record_activity), never edited.
  class Activity < ApplicationRecord
    KINDS = %w[
      created submitted
      email_sent email_opened email_clicked unsubscribed resubscribed
      stage_changed qualified score_changed
      note task_created task_done
      enrolled enrollment_stopped enrollment_completed
    ].freeze

    belongs_to :lead, class_name: "Leads::Lead", inverse_of: :activities
    belongs_to :user, class_name: "::User", optional: true

    validates :kind, inclusion: {in: KINDS}
    validates :summary, presence: true

    scope :newest_first, -> { order(created_at: :desc, id: :desc) }

    def note? = kind == "note"
  end
end
