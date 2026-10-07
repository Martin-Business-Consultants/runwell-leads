# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe "Leads › Sequences", type: :request do
  let(:admin) { create(:user) }

  before do
    sign_in_as admin
    ActionMailer::Base.deliveries.clear
  end

  it "lists sequences with their steps and who's in them" do
    sequence = make_sequence("Welcome")
    make_lead.enroll(sequence)

    get leads_sequences_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Welcome", "Manual", "Active")
  end

  it "creates a sequence with its steps in the order the editor posts them" do
    get new_leads_sequence_path
    expect(response).to have_http_status(:ok)

    post leads_sequences_path, params: {sequence: {name: "Nurture", active: "1", trigger: "stage", trigger_stage: "qualified",
      steps: {"zz" => {subject: "First", delay_amount: "0", delay_unit: "hours", body: "Hi"},
              "aa" => {subject: "Second", delay_amount: "3", delay_unit: "days", body: "Again"}}}}

    sequence = Leads::Sequence.find_by!(name: "Nurture")
    expect(response).to redirect_to(edit_leads_sequence_path(sequence))
    expect(sequence).to have_attributes(trigger: "stage", trigger_stage: "qualified", active: true)
    expect(sequence.steps.map(&:subject)).to eq %w[First Second]
  end

  it "draws the editor with a row per step, and round-trips it" do
    sequence = make_sequence("Welcome", steps: 2)

    get edit_leads_sequence_path(sequence)
    expect(response).to have_http_status(:ok)
    doc = Nokogiri::HTML(response.body)
    expect(doc.css("[data-sortable-list-target='list'] > li").size).to eq 2

    submit_form_pairs(:patch, leads_sequence_path(sequence), form_pairs(response.body, "sequence_form"))
    expect(response).to redirect_to(edit_leads_sequence_path(sequence))
    expect(sequence.reload.steps.map(&:subject)).to eq ["Step 1 for {{first_name}}", "Step 2 for {{first_name}}"]
  end

  it "shows what's wrong with a step" do
    sequence = make_sequence

    patch leads_sequence_path(sequence), params: {sequence: {name: "Welcome", steps: {"a" => {subject: "", delay_amount: "1", delay_unit: "days"}}}}

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Subject can&#39;t be blank")
  end

  it "previews the emails and sends the steps as a test to the person asking" do
    sequence = make_sequence(steps: 2)

    get leads_sequence_preview_path(sequence)
    expect(response.body).to include("Step 1 for Jamie", "srcdoc")

    post leads_sequence_test_path(sequence)
    expect(ActionMailer::Base.deliveries.map(&:to).flatten.uniq).to eq [admin.email]
    expect(ActionMailer::Base.deliveries.map(&:subject)).to all(start_with("[Test]"))
  end

  it "deletes a sequence" do
    sequence = make_sequence

    delete leads_sequence_path(sequence)

    expect(Leads::Sequence.count).to eq 0
  end
end
