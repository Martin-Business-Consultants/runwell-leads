# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::SequenceMailer do
  let(:lead) { make_lead("ada@example.com", name: "Ada Park", company: "Park & Co") }
  let(:sequence) { make_sequence(steps: 1) }
  let(:step) { sequence.steps.first }

  it "sends a lead its step, personalized, with tracked links, the open pixel and the unsubscribe link" do
    step.update!(body: "Hi {{first_name}} at {{company}},\n\n[Menu](https://example.com/menu) and <script>alert(1)</script>")
    message = lead.messages.create!(step: step, subject: step.email_for(lead).subject)

    mail = Leads::SequenceMailer.with(message: message).step_email
    html = mail.html_part.body.decoded

    expect(mail.subject).to eq "Step 1 for Ada"
    expect(mail.to).to eq ["ada@example.com"]
    expect(html).to include("Hi Ada at Park &amp; Co")
    expect(html).not_to include("<script>", "https://example.com/menu\"")
    click = Nokogiri::HTML(html).at_css("a[href*='/click']")["href"]
    expect(Leads::Message.find_by_click_token(click[%r{/leads/mail/([^/]+)/click}, 1])).to eq [message, "https://example.com/menu"]
    expect(html).to include("/leads/mail/#{message.open_token}/open", "/leads/mail/#{lead.unsubscribe_token}/unsubscribe")
    expect(mail["List-Unsubscribe"].value).to include(lead.unsubscribe_token)
    expect(mail["List-Unsubscribe-Post"].value).to eq "List-Unsubscribe=One-Click"
    expect(mail.text_part.body.decoded).to include("Hi Ada at Park & Co", "Unsubscribe: http://example.com/leads/mail/")
  end

  it "sends a test untracked, marked as a test" do
    mail = Leads::SequenceMailer.with(step: step, lead: Leads::Lead.new(email: "me@example.com", name: "Me")).test_email
    html = mail.html_part.body.decoded

    expect(mail.subject).to eq "[Test] Step 1 for Me"
    expect(html).to include("https://example.com/menu")
    expect(html).not_to include("/leads/mail/")
    expect(mail["List-Unsubscribe"]).to be_nil
  end
end
