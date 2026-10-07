# frozen_string_literal: true

# Sending a sequence's emails. Every few minutes (Cms::Plugins.minutely in
# lib/leads/engine.rb) the plugin queues Leads::Enrollment::DeliveryJob,
# which sends every enrollment's due step: one email (Leads::Message), an
# "email sent" activity, and the next step scheduled its delay after this
# one, or the enrollment completed when this was the last.
module Leads::Enrollment::Deliverable
  extend ActiveSupport::Concern

  # When a step that failed to send is tried again.
  RETRY_AFTER = 15.minutes

  included do
    # Active, due, in a sequence that's switched on.
    scope :due, ->(now = Time.current) {
      active.where(next_send_at: ..now).joins(:sequence).merge(Leads::Sequence.active)
    }
  end

  class_methods do
    def deliver_due_later
      Leads::Enrollment::DeliveryJob.perform_later
    end

    # Returns how many emails went. One that fails is logged, tried again
    # later, and doesn't stop the others.
    def deliver_due_now(now = Time.current)
      due(now).includes(:lead, :sequence).find_each.count do |enrollment|
        enrollment.deliver_now(now)
      rescue StandardError => e
        Rails.logger.error("[leads] enrollment #{enrollment.id}: #{e.class}: #{e.message}")
        false
      end
    end
  end

  # Sends the due step, once: a run first claims it (clearing next_send_at
  # where it's still due), so two runs at once can't both send it. Returns
  # whether an email went.
  def deliver_now(now = Time.current)
    return false unless claim(now)

    if !lead.sendable?
      stop(reason: lead.unsubscribed? ? "unsubscribed" : lead.stage)
      false
    elsif (step = next_step)
      send_step(step, now)
      true
    else
      complete
      false
    end
  end

  private

  def claim(now)
    claimed = self.class.active.where(id: id, current_step: current_step, next_send_at: ..now)
      .update_all(next_send_at: nil, updated_at: now)
    reload if claimed == 1
    claimed == 1
  end

  def send_step(step, now)
    message = lead.messages.create!(enrollment: self, step: step, subject: step.email_for(lead).subject)
    begin
      message.deliver_now
    rescue StandardError
      message.destroy!
      update_columns(next_send_at: now + RETRY_AFTER)
      raise
    end
    lead.record_activity(:email_sent, summary: "Sent “#{message.subject}”", user: nil,
      data: {message_id: message.id, sequence_id: sequence_id, step: step.number})

    following = sequence.steps[current_step + 1]
    update!(current_step: current_step + 1, last_sent_at: now, next_send_at: following&.send_after(now))
    complete unless following
  end
end
