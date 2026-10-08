module Leads
  # A follow-up on a lead: what to do, by when, and who does it. Adding one and finishing it go on
  # the lead's timeline; what's due shows on the assignee's home page.
  class Task < ApplicationRecord
    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :assignee, class_name: "::User", optional: true
    belongs_to :creator, class_name: "::User", optional: true

    validates :title, presence: true, length: { maximum: 200 }

    scope :pending, -> { where(done_at: nil) }
    scope :done, -> { where.not(done_at: nil) }
    scope :assigned_to, ->(user) { where(assignee: user) }
    scope :due_by, ->(date) { where(due_on: ..date) }
    scope :overdue, -> { pending.where(due_on: ...Date.current) }
    # Overdue first, then by due date (undated last), then the oldest.
    scope :in_due_order, -> { order(Arel.sql("CASE WHEN leads_tasks.due_on IS NULL THEN 1 ELSE 0 END"), :due_on, :created_at) }

    def done? = done_at.present?
    def overdue? = !done? && due_on.present? && due_on < Date.current

    # Made on a lead by someone: on its timeline.
    def self.assign(lead, attributes, user: Current.user)
      task = lead.tasks.new(attributes)
      task.creator = user
      task.assignee ||= user&.person
      if task.save
        lead.record_activity(:task_created, summary: "Task added: #{task.title}", data: { task_id: task.id }, user: user)
      end
      task
    end

    def complete(user: Current.user)
      return false if done?

      update!(done_at: Time.current)
      lead.record_activity(:task_done, summary: "Task done: #{title}", data: { task_id: id }, user: user)
      true
    end

    def reopen
      return false unless done?

      update!(done_at: nil)
    end
  end
end
