# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe "Settings › Leads", type: :request do
  before { sign_in_as create(:user) }

  it "shows scoring, the sender and a row per form, and saves them" do
    form = make_form
    sequence = make_sequence

    get settings_leads_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Scoring", "Qualifies at", "Contact", "Welcome")

    patch settings_leads_path, params: {settings: {threshold: "40", from_name: "Mill", from_email: "mill@example.com",
      points: {submission: "12", email_open: "1", email_click: "4", note: "1"},
      capture: {contact: {enabled: "0", sequence_id: sequence.id.to_s}}}}

    expect(response).to redirect_to(settings_leads_path)
    settings = Leads::Settings.current
    expect(settings.threshold).to eq 40
    expect(settings.points_for(:submission)).to eq 12
    expect(settings.capture?(form)).to be false
    expect(settings.sequence_id_for(form)).to eq sequence.id
  end

  it "round-trips the form as the browser posts it" do
    make_form

    get settings_leads_path
    submit_form_pairs(:patch, settings_leads_path, form_pairs(response.body, "settings_form"))

    expect(Leads::Settings.current.capture?(Form.first)).to be true
    expect(Leads::Settings.current.threshold).to eq 50
  end
end
