module Leads
  # One thing on a lead's timeline: coming in from the website, an email sent, opened or clicked,
  # a change of stage or score, a note, a task, a sequence started or left, becoming a client.
  # Made by the lead's verbs (Lead#record_activity), never edited.
  class Activity < ApplicationRecord
    KINDS = %w[
      created captured
      email_sent email_opened email_clicked unsubscribed resubscribed
      stage_changed qualified score_changed
      note task_created task_done
      enrolled enrollment_stopped enrollment_completed
      converted
    ].freeze

    belongs_to :lead, class_name: "Leads::Lead", inverse_of: :activities
    belongs_to :user, class_name: "::User", optional: true

    validates :kind, inclusion: { in: KINDS }
    validates :summary, presence: true

    def note? = kind == "note"
  end
end
