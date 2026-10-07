# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Lead::Scored do
  let(:lead) { make_lead }

  it "adjusts the score by hand, with the reason on the timeline and in the audit log" do
    lead.adjust_score(5, reason: "Asked for a quote")

    expect(lead.reload.score).to eq 5
    expect(lead.activities.first).to have_attributes(kind: "score_changed", points: 5, summary: "Score adjusted by +5: Asked for a quote")
    expect(AuditLog.where(action: "lead.score_adjusted").sole.metadata).to include("points" => 5)
  end

  it "refuses zero or a non-number" do
    expect { lead.adjust_score(0, reason: "x") }.to raise_error(ArgumentError)
    expect { lead.adjust_score("lots", reason: "x") }.to raise_error(ArgumentError)
  end

  it "qualifies a new or nurturing lead that crosses the threshold, once, and says so" do
    Leads::Settings.update("threshold" => "20")
    announced = []
    subscriber = ActiveSupport::Notifications.subscribe("lead.qualified.cms") { announced << it.payload[:data][:id] }

    lead.adjust_score(15, reason: "Call")
    expect(lead.reload.stage).to eq "new"

    lead.adjust_score(10, reason: "Demo")
    lead.adjust_score(10, reason: "Another")

    expect(lead.reload.stage).to eq "qualified"
    expect(lead.activities.where(kind: "qualified").count).to eq 1
    expect(lead.activities.where(kind: "stage_changed").sole.summary).to eq "Stage changed from New to Qualified"
    expect(announced).to eq [lead.id]
    expect(AuditLog.where(action: "lead.stage_changed")).to be_empty
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "leaves a customer's stage alone however high the score" do
    lead.update!(stage: "customer")
    lead.adjust_score(100, reason: "Big order")

    expect(lead.reload.stage).to eq "customer"
  end
end
