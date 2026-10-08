# Sending a sequence's emails. Each time an enrollment's next email is scheduled, a job is queued
# for that moment (schedule_delivery); the nightly run sweeps up any that are due and weren't sent
# (a sequence switched back on, a failed send, a restart). Sending is one email (Leads::Message), an
# "email sent" activity, and the next email scheduled its delay after this one, or the enrollment
# completed when this was the last.
module Leads::Enrollment::Deliverable
  extend ActiveSupport::Concern

  # When an email that failed to send is tried again.
  RETRY_AFTER = 15.minutes

  included do
    # Active, due, in a sequence that's switched on.
    scope :due, ->(now = Time.current) { active.where(next_send_at: ..now).joins(:sequence).merge(Leads::Sequence.active) }
  end

  class_methods do
    def deliver_due_later = Leads::Enrollment::DeliveryJob.perform_later

    # Returns how many emails went. One that fails is logged, tried again later, and doesn't stop
    # the others.
    def deliver_due_now(now = Time.current)
      due(now).includes(:lead, sequence: :steps).find_each.count do |enrollment|
        enrollment.deliver_now(now)
      rescue StandardError => e
        Rails.logger.error("[leads] enrollment #{enrollment.id}: #{e.class}: #{e.message}")
        false
      end
    end
  end

  def schedule_delivery
    Leads::Enrollment::DeliveryJob.set(wait_until: next_send_at).perform_later(id) if active? && next_send_at
  end

  # Sends the due email, once: a run first claims it (clearing next_send_at where it's still due),
  # so two runs at once can't both send it. Returns whether an email went.
  def deliver_now(now = Time.current)
    return false unless sequence.active? && claim(now)

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
        update!(next_send_at: now + RETRY_AFTER)
        schedule_delivery
        raise
      end
      lead.record_activity(:email_sent, summary: "Sent “#{message.subject}”", user: nil,
        data: { message_id: message.id, sequence_id: sequence_id, step: step.number })

      following = sequence.steps[current_step + 1]
      update!(current_step: current_step + 1, last_sent_at: now, next_send_at: following&.send_after(now))
      following ? schedule_delivery : complete
    end
end
