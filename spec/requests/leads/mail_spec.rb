# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

# The routes an email's links reach: public, signed.
RSpec.describe "Leads › email links", type: :request do
  let(:lead) { make_lead }
  let(:message) { lead.messages.create!(subject: "Hello", sent_at: Time.current) }

  it "answers the open pixel with a GIF, marking the email opened" do
    get leads_mail_open_path(token: message.open_token)

    expect(response.media_type).to eq "image/gif"
    expect(message.reload.opened_at).to be_present
  end

  it "answers a forged pixel with the GIF too, changing nothing" do
    get leads_mail_open_path(token: "forged")

    expect(response.media_type).to eq "image/gif"
    expect(Leads::Activity.count).to eq 0
  end

  it "follows a tracked link to where it pointed, and nowhere else" do
    get leads_mail_click_path(token: message.click_token("https://example.com/menu"))
    expect(response).to redirect_to("https://example.com/menu")
    expect(lead.activities.where(kind: "email_clicked")).to exist

    get leads_mail_click_path(token: "forged")
    expect(response).to have_http_status(:not_found)
  end

  it "asks before unsubscribing, then unsubscribes in one click" do
    enrollment = lead.enroll(make_sequence)

    get leads_mail_unsubscribe_path(token: lead.unsubscribe_token)
    expect(response.body).to include("Unsubscribe?", "sam@example.com")
    expect(lead.reload).not_to be_unsubscribed

    post leads_mail_unsubscribe_path(token: lead.unsubscribe_token)
    expect(response.body).to include("You’re unsubscribed")
    expect(lead.reload).to be_unsubscribed
    expect(enrollment.reload.status).to eq "stopped"
  end

  it "takes a mail client's one-click unsubscribe (RFC 8058)" do
    post leads_mail_unsubscribe_path(token: lead.unsubscribe_token), params: {"List-Unsubscribe" => "One-Click"}

    expect(response).to have_http_status(:ok)
    expect(lead.reload).to be_unsubscribed
  end

  it "says a broken link doesn't work" do
    get leads_mail_unsubscribe_path(token: "forged")

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("That link doesn’t work")
  end

  it "is gone while the plugin is off" do
    switch_plugin :leads, on: false

    get leads_mail_unsubscribe_path(token: lead.unsubscribe_token)

    expect(response).to have_http_status(:not_found)
  end
end
