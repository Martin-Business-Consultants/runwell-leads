# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Lead::Staged do
  let(:lead) { make_lead }

  it "records a change of stage, and announces it with the stage it left" do
    payloads = []
    subscriber = ActiveSupport::Notifications.subscribe("lead.stage_changed.cms") { payloads << it.payload[:data] }

    expect(lead.change_stage("qualified")).to be true
    expect(lead.change_stage("qualified")).to be false

    expect(lead.activities.sole).to have_attributes(kind: "stage_changed", data: {"from" => "new", "to" => "qualified"})
    expect(payloads.sole).to include(stage: "qualified", previous_stage: "new")
    expect(AuditLog.where(action: "lead.stage_changed").count).to eq 1
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "takes a customer or a lost lead out of its sequences" do
    enrollment = lead.enroll(make_sequence)

    lead.change_stage("customer")

    expect(enrollment.reload).to have_attributes(status: "stopped", stop_reason: "customer")
  end

  it "enrolls the lead in the active sequences that start at the stage it reaches" do
    qualified = make_sequence("Qualified", trigger: "stage", trigger_stage: "qualified")
    make_sequence("Off", trigger: "stage", trigger_stage: "qualified", active: false)

    lead.change_stage("qualified")

    expect(lead.enrollments.map(&:sequence)).to eq [qualified]
  end

  it "revises details and stage together, keeping errors on the lead" do
    expect(lead.revise({name: "Sam L", stage: "lost"})).to be true
    expect(lead.reload).to have_attributes(name: "Sam L", stage: "lost")

    expect(lead.revise({email: "nope"})).to be false
    expect(lead.errors[:email]).to be_present
    expect(lead.revise({stage: "won"})).to be false
  end

  it "changes the stage of many leads, recording which" do
    leads = [lead, make_lead("b@example.com"), make_lead("c@example.com", stage: "lost")]

    changed = Leads::Lead.change_stage_of(leads, to: "lost")

    expect(changed.map(&:email)).to contain_exactly("sam@example.com", "b@example.com")
    expect(AuditLog.where(action: "lead.bulk_stage_changed").sole.metadata["emails"]).to contain_exactly("sam@example.com", "b@example.com")
  end
end
