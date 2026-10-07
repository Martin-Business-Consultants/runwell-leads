# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Message do
  let(:lead) { make_lead }
  let(:message) { lead.messages.create!(subject: "Hello", sent_at: Time.current) }

  it "scores the first open only" do
    expect(message.record_open).to be true
    expect(message.record_open).to be false

    expect(lead.reload.score).to eq 1
    expect(lead.activities.where(kind: "email_opened").count).to eq 1
  end

  it "scores the first click, notes every click, and counts a click as an open" do
    message.record_click("https://example.com/menu")
    message.record_click("https://example.com/menu")

    expect(lead.reload.score).to eq 1 + 3
    expect(lead.activities.where(kind: "email_clicked").count).to eq 2
    expect(lead.activities.where(kind: "email_clicked").first.summary).to eq "Clicked example.com in “Hello”"
    expect(message.reload).to have_attributes(opened_at: be_present, clicked_at: be_present)
  end

  it "signs its tokens, the click's with the URL it leads to" do
    expect(Leads::Message.find_by_open_token(message.open_token)).to eq message
    expect(Leads::Message.find_by_click_token(message.click_token("https://example.com/a"))).to eq [message, "https://example.com/a"]
    expect(Leads::Message.find_by_click_token(message.click_token("javascript:alert(1)"))).to be_nil
    expect(Leads::Message.find_by_open_token("forged")).to be_nil
  end
end
