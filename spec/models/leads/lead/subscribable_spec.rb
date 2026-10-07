# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Lead::Subscribable do
  let(:lead) { make_lead }

  it "finds the lead by its signed token, and nothing by a forged one" do
    expect(Leads::Lead.find_by_unsubscribe_token(lead.unsubscribe_token)).to eq lead
    expect(Leads::Lead.find_by_unsubscribe_token(lead.id.to_s)).to be_nil
    expect(Leads::Lead.find_by_unsubscribe_token("#{lead.unsubscribe_token}x")).to be_nil
  end

  it "unsubscribes once, stopping its sequences and refusing new ones" do
    sequence = make_sequence
    enrollment = lead.enroll(sequence)

    expect(lead.unsubscribe).to be true
    expect(lead.unsubscribe).to be false

    expect(lead.reload.unsubscribed_at).to be_present
    expect(enrollment.reload).to have_attributes(status: "stopped", stop_reason: "unsubscribed")
    expect(lead.enroll(sequence)).to be_nil
    expect(lead.enrollment_refusal(sequence)).to include("unsubscribed")
  end

  it "can be put back on the list" do
    lead.unsubscribe
    lead.resubscribe

    expect(lead.reload).not_to be_unsubscribed
    expect(lead.activities.first.kind).to eq "resubscribed"
  end
end
