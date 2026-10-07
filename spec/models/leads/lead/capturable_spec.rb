# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Lead::Capturable do
  include ActiveJob::TestHelper

  let(:form) { make_form }

  def submit_form(data, form_record = form)
    form_record.submissions.create!(data: data, meta: {}, ip: "1.2.3.4")
  end

  it "makes a lead from a submission, with a submitted activity worth its points" do
    lead = Leads::Lead.capture_now(submit_form("name" => "Ada Park", "email" => " Ada@Example.com ", "phone" => "555-0100", "message" => "Hi"))

    expect(lead).to have_attributes(email: "ada@example.com", name: "Ada Park", phone: "555-0100", source: "form",
      source_form_id: form.id, stage: "new", score: 10)
    expect(lead.fields).to include("message" => "Hi")
    expect(lead.activities.sole).to have_attributes(kind: "submitted", summary: "Submitted Contact", points: 10)
  end

  it "updates the lead for the same address rather than making another" do
    Leads::Lead.capture_now(submit_form("name" => "Ada", "email" => "ada@example.com"))
    lead = Leads::Lead.capture_now(submit_form("email" => "ADA@example.com", "message" => "Again"))

    expect(Leads::Lead.count).to eq 1
    expect(lead).to have_attributes(name: "Ada", score: 20)
    expect(lead.fields).to eq("email" => "ADA@example.com", "message" => "Again")
    expect(lead.activities.where(kind: "submitted").count).to eq 2
  end

  it "says lead.created once, for a new lead" do
    announced = []
    subscriber = ActiveSupport::Notifications.subscribe("lead.created.cms") { |event| announced << event.payload[:data][:email] }

    Leads::Lead.capture_now(submit_form("email" => "ada@example.com"))
    Leads::Lead.capture_now(submit_form("email" => "ada@example.com"))

    expect(announced).to eq ["ada@example.com"]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "skips a submission without a valid email address" do
    expect(Leads::Lead.capture_now(submit_form("name" => "No address"))).to be_nil
    expect(Leads::Lead.capture_now(submit_form("email" => "not-an-address"))).to be_nil
    expect(Leads::Lead.count).to eq 0
  end

  it "finds the address in the form's email field whatever it's called" do
    other = make_form("signup", fields: [{"name" => "your_address", "label" => "Address", "type" => "email"},
      {"name" => "first_name", "label" => "First", "type" => "text"}, {"name" => "last_name", "label" => "Last", "type" => "text"},
      {"name" => "organization", "label" => "Organization", "type" => "text"}])

    lead = Leads::Lead.capture_now(submit_form({"your_address" => "jo@example.com", "first_name" => "Jo", "last_name" => "Ng",
      "organization" => "Ng Ltd"}, other))

    expect(lead).to have_attributes(email: "jo@example.com", name: "Jo Ng", company: "Ng Ltd")
  end

  it "leaves a form alone that Settings › Leads switched off" do
    Leads::Settings.update("capture" => {"contact" => {"enabled" => "0"}})

    expect(Leads::Lead.capture_now(submit_form("email" => "ada@example.com"))).to be_nil
  end

  it "enrolls a new lead in its form's sequence, and any lead in sequences the form triggers" do
    welcome = make_sequence("Welcome")
    follow_up = make_sequence("Follow-up", trigger: "form", trigger_form_id: form.id)
    Leads::Settings.update("capture" => {"contact" => {"enabled" => "1", "sequence_id" => welcome.id.to_s}})

    lead = Leads::Lead.capture_now(submit_form("email" => "ada@example.com"))
    Leads::Lead.capture_now(submit_form("email" => "ada@example.com"))

    expect(lead.enrollments.map(&:sequence)).to contain_exactly(welcome, follow_up)
    expect(lead.reload.stage).to eq "nurturing"
  end

  it "is queued for every submission.created while the plugin is on" do
    expect { submit_form("email" => "ada@example.com") }.to have_enqueued_job(Leads::Lead::CaptureJob)

    perform_enqueued_jobs(only: Leads::Lead::CaptureJob)
    expect(Leads::Lead.find_by(email: "ada@example.com")).to be_present
  end

  it "isn't queued while the plugin is off" do
    switch_plugin :leads, on: false

    expect { submit_form("email" => "ada@example.com") }.not_to have_enqueued_job(Leads::Lead::CaptureJob)
  end
end
