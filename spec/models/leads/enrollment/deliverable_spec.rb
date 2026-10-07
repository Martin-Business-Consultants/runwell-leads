# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Enrollment::Deliverable do
  include ActiveJob::TestHelper

  let(:lead) { make_lead }
  let(:sequence) { make_sequence(steps: 2) }

  before { ActionMailer::Base.deliveries.clear }

  it "sends the first step at once when its delay is nothing, then waits the next step's delay" do
    freeze_time do
      enrollment = lead.enroll(sequence)
      expect(enrollment.next_send_at).to eq Time.current

      expect(Leads::Enrollment.deliver_due_now).to eq 1

      mail = ActionMailer::Base.deliveries.sole
      expect(mail.to).to eq ["sam@example.com"]
      expect(mail.subject).to eq "Step 1 for Sam"
      expect(enrollment.reload).to have_attributes(current_step: 1, last_sent_at: Time.current, next_send_at: 2.days.from_now)
      expect(lead.activities.first).to have_attributes(kind: "email_sent", summary: "Sent “Step 1 for Sam”")
    end
  end

  it "completes after the last step" do
    enrollment = lead.enroll(sequence)
    enrollment.deliver_now
    travel 2.days + 1.minute do
      Leads::Enrollment.deliver_due_now
    end

    expect(enrollment.reload).to have_attributes(status: "completed", current_step: 2, next_send_at: nil)
    expect(lead.messages.count).to eq 2
    expect(lead.activities.first.kind).to eq "enrollment_completed"
  end

  it "sends nothing that isn't due, or from a sequence that's off" do
    enrollment = lead.enroll(sequence)
    enrollment.update!(next_send_at: 1.hour.from_now)
    expect(Leads::Enrollment.deliver_due_now).to eq 0

    enrollment.update!(next_send_at: 1.hour.ago)
    sequence.update!(active: false)
    expect(Leads::Enrollment.deliver_due_now).to eq 0
    expect(ActionMailer::Base.deliveries).to be_empty
  end

  it "sends a due step once, however many runs reach it" do
    enrollment = lead.enroll(sequence)
    stale = Leads::Enrollment.find(enrollment.id)

    expect(enrollment.deliver_now).to be true
    expect(stale.deliver_now).to be false
    expect(ActionMailer::Base.deliveries.size).to eq 1
  end

  it "stops instead of sending to a lead that can't be emailed any more" do
    enrollment = lead.enroll(sequence)
    lead.update_columns(stage: "lost")

    expect(enrollment.deliver_now).to be false
    expect(enrollment.reload).to have_attributes(status: "stopped", stop_reason: "lost")
  end

  it "tries a step that failed to send again later" do
    allow_any_instance_of(Leads::Message).to receive(:deliver_now).and_raise(Net::SMTPServerBusy)

    freeze_time do
      enrollment = lead.enroll(sequence)
      expect(Leads::Enrollment.deliver_due_now).to eq 0
      expect(enrollment.reload).to have_attributes(current_step: 0, next_send_at: 15.minutes.from_now)
      expect(Leads::Message.count).to eq 0
    end
  end

  it "is queued by the plugin's minutely task" do
    task = Cms::Plugins.minutely_tasks[:leads][:sequences]

    expect { task.task.call }.to have_enqueued_job(Leads::Enrollment::DeliveryJob)
    expect(task.every).to eq 5
  end
end
