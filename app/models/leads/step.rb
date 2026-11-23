module Leads
  # One thing to do on a lead, by a date: laid out from its stage's plan when it arrives there
  # (PlaybookStep), added by hand, or planned after a call. A lead's next step is always its
  # earliest open one (Lead#sync_next_step!), so the table, the board, the morning email and an
  # agent all read the same thing. A step that starts from an email template says so, and its page
  # offers to write that email.
  class Step < ApplicationRecord
    self.table_name = "leads_steps"

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :playbook_step, class_name: "Leads::PlaybookStep", optional: true
    belongs_to :template, class_name: "Leads::Template", optional: true
    belongs_to :done_by, class_name: "User", optional: true
    belongs_to :created_by, class_name: "User", optional: true

    normalizes :title, with: ->(title) { title.to_s.squish }
    validates :title, presence: true, length: { maximum: 200 }

    scope :open, -> { where(done_at: nil) }
    scope :done, -> { where.not(done_at: nil) }
    # Soonest first, undated last, then in the order they were planned.
    scope :in_order, -> { order(Arel.sql("leads_steps.due_on IS NULL, leads_steps.due_on, leads_steps.id")) }
    scope :due_by, ->(date) { open.where(due_on: ..date) }

    def done? = done_at.present?
    def overdue? = !done? && due_on.present? && due_on < Date.current
    def due_today? = !done? && due_on == Date.current
  end
end
