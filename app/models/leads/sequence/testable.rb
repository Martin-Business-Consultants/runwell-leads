# frozen_string_literal: true

# "Send test": every step of the sequence to someone on the team, at once, as
# a lead with their name and address would get it — links untracked, the
# subject marked as a test.
module Leads::Sequence::Testable
  extend ActiveSupport::Concern

  def send_test(to:)
    lead = Leads::Lead.new(email: to.email, name: to.name)
    kept_steps.each do |step|
      Leads::SequenceMailer.with(step: step, lead: lead).test_email.deliver_now
    end
    track_event(:test_sent, to: to.email, steps: kept_steps.size)
    kept_steps.size
  end
end
