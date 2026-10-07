# frozen_string_literal: true

module Leads
  # A follow-up on a lead: what to do, by when, and who does it. Creating
  # one and finishing it go on the lead's timeline.
  class Task < ApplicationRecord
    include Eventable

    def self.eventable_prefix = "lead_task"

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :assignee, class_name: "::User", optional: true
    belongs_to :creator, class_name: "::User", optional: true

    validates :title, presence: true, length: {maximum: 200}

    scope :pending, -> { where(done_at: nil) }
    scope :done, -> { where.not(done_at: nil) }
    scope :assigned_to, ->(user) { where(assignee: user) }
    scope :due_by, ->(date) { where(due_on: ..date) }
    scope :overdue, -> { pending.where(due_on: ...Date.current) }
    # Overdue first, then by due date (undated last), then the oldest.
    scope :in_due_order, -> { order(Arel.sql("CASE WHEN leads_tasks.due_on IS NULL THEN 1 ELSE 0 END"), :due_on, :created_at) }

    after_create_commit -> { announce("lead_task.created") }

    def done? = done_at.present?

    def overdue? = !done? && due_on.present? && due_on < Date.current

    def due_today? = !done? && due_on == Date.current

    # Made on a lead by someone (or the API): on the timeline and in the audit log.
    def self.assign(lead, attributes, user: Current.user)
      task = lead.tasks.new(attributes)
      task.creator = user
      if task.save
        lead.record_activity(:task_created, summary: "Task added: #{task.title}", data: {task_id: task.id}, user: user)
        task.track_event(:created, title: task.title, lead: lead.email)
      end
      task
    end

    def complete(user: Current.user)
      return false if done?

      update!(done_at: Time.current)
      lead.record_activity(:task_done, summary: "Task done: #{title}", data: {task_id: id}, user: user)
      track_event(:completed, title: title, lead: lead.email)
      true
    end

    def reopen
      return false unless done?

      update!(done_at: nil)
      track_event(:reopened, title: title, lead: lead.email)
      true
    end

    def webhook_payload
      {
        id:             id,
        title:          title,
        due_on:         due_on&.iso8601,
        done_at:        done_at&.iso8601,
        assignee_email: assignee&.email,
        lead:           {id: lead.id, email: lead.email, name: lead.name},
        created_at:     created_at&.iso8601
      }
    end
  end
end
