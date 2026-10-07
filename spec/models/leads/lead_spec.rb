# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Lead do
  it "keeps one lead per address, case and spaces aside" do
    make_lead("Sam@Example.com ")

    expect(Leads::Lead.new(email: "sam@example.com")).not_to be_valid
    expect(Leads::Lead.sole.email).to eq "sam@example.com"
  end

  it "is forgotten with everything it holds" do
    lead = make_lead
    lead.add_note("Called")
    Leads::Task.assign(lead, {title: "Call back"})
    enrollment = lead.enroll(make_sequence)
    enrollment.update!(next_send_at: 1.minute.ago)
    enrollment.deliver_now

    lead.forget

    expect([Leads::Lead, Leads::Activity, Leads::Task, Leads::Enrollment, Leads::Message].map(&:count)).to all(eq 0)
    expect(AuditLog.where(action: "lead.deleted").sole.metadata).to include("email" => "sam@example.com")
  end

  it "starts a lead added by hand with an activity, an audit row and lead.created" do
    lead = make_lead(source: "manual")
    announced = []
    subscriber = ActiveSupport::Notifications.subscribe("lead.created.cms") { announced << it.payload[:data][:email] }

    lead.record_creation

    expect(lead.activities.sole.kind).to eq "created"
    expect(AuditLog.where(action: "lead.created").sole.metadata).to include("source" => "manual")
    expect(announced).to eq ["sam@example.com"]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
