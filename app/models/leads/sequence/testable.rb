# "Send a test": every email of the sequence to someone on the team, at once, as a lead with their
# name and address would get it: links untracked, the subject marked as a test.
module Leads::Sequence::Testable
  extend ActiveSupport::Concern

  def send_test(to:)
    steps.each { Leads::SequenceMailer.with(step: it, to: to.person).test_email.deliver_later }
    steps.size
  end
end
