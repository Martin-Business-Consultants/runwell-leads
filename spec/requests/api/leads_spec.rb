# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe "API › Leads", type: :request do
  let(:admin) { create(:user) }

  def api_headers(user = admin) = {"Authorization" => "Bearer #{user.api_token.token}"}

  it "lists leads, filtered by stage and search" do
    make_lead("a@example.com", name: "Ada", stage: "qualified")
    make_lead("b@example.com", name: "Bo")

    get "/api/leads", params: {stage: "qualified"}, headers: api_headers

    body = response.parsed_body
    expect(body["leads"].map { it["email"] }).to eq ["a@example.com"]
    expect(body).to include("page" => 1, "per" => 25, "total" => 1)

    get "/api/leads", params: {q: "bo"}, headers: api_headers
    expect(response.parsed_body["leads"].map { it["name"] }).to eq ["Bo"]
  end

  it "creates a lead, or updates the one with that address" do
    post "/api/leads", params: {lead: {email: "New@Example.com", name: "New"}}, headers: api_headers, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("email" => "new@example.com", "source" => "api", "stage" => "new")
    expect(response.parsed_body["activities"].sole["summary"]).to eq "Added through the API"

    post "/api/leads", params: {lead: {email: "new@example.com", company: "Co", stage: "qualified"}}, headers: api_headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(Leads::Lead.sole).to have_attributes(company: "Co", stage: "qualified", name: "New")
  end

  it "refuses an invalid lead" do
    post "/api/leads", params: {lead: {email: "nope"}}, headers: api_headers, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["error"]).to eq "invalid"
  end

  it "shows a lead with its timeline, tasks and enrollments; updates and deletes it" do
    lead = make_lead
    lead.add_note("Hi")
    Leads::Task.assign(lead, {title: "Call"})
    lead.enroll(make_sequence)

    get "/api/leads/#{lead.id}", headers: api_headers
    body = response.parsed_body
    expect(body["activities"].map { it["kind"] }).to include("note", "task_created", "enrolled")
    expect(body["tasks"].sole["title"]).to eq "Call"
    expect(body["enrollments"].sole).to include("sequence" => "Welcome", "status" => "active")

    patch "/api/leads/#{lead.id}", params: {lead: {stage: "customer"}}, headers: api_headers, as: :json
    expect(response.parsed_body["stage"]).to eq "customer"
    expect(AuditLog.where(action: "lead.stage_changed").sole.metadata).to include("via" => "api")

    delete "/api/leads/#{lead.id}", headers: api_headers
    expect(response).to have_http_status(:no_content)
    expect(Leads::Lead.count).to eq 0
  end

  it "adds notes, tasks, score adjustments and enrollments under a lead" do
    lead = make_lead
    sequence = make_sequence

    post "/api/leads/#{lead.id}/notes", params: {note: {body: "Called"}}, headers: api_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to include("kind" => "note", "body" => "Called")

    post "/api/leads/#{lead.id}/tasks", params: {task: {title: "Quote", due_on: "2026-12-01"}}, headers: api_headers, as: :json
    expect(response.parsed_body).to include("title" => "Quote", "due_on" => "2026-12-01")

    get "/api/leads/#{lead.id}/tasks", headers: api_headers
    expect(response.parsed_body["tasks"].map { it["title"] }).to eq ["Quote"]

    post "/api/leads/#{lead.id}/score_adjustments", params: {score_adjustment: {points: 4, reason: "Replied"}}, headers: api_headers, as: :json
    expect(response.parsed_body["score"]).to eq 4

    post "/api/leads/#{lead.id}/enrollments", params: {enrollment: {sequence_id: sequence.id}}, headers: api_headers, as: :json
    expect(response).to have_http_status(:created)
    post "/api/leads/#{lead.id}/enrollments", params: {enrollment: {sequence_id: sequence.id}}, headers: api_headers, as: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body["message"]).to include("already in")
  end

  it "lists the sequences and the open tasks across leads" do
    make_sequence("Welcome", steps: 2)
    Leads::Task.assign(make_lead, {title: "Late", due_on: 2.days.ago.to_date, assignee_id: admin.id})

    get "/api/leads/sequences", headers: api_headers
    expect(response.parsed_body["sequences"].sole["steps"].size).to eq 2

    get "/api/leads/tasks", params: {assignee: "me", overdue: 1}, headers: api_headers
    expect(response.parsed_body["tasks"].sole).to include("title" => "Late", "overdue" => true)
  end

  it "refuses a token without the capability" do
    reader = create(:user, admin: false, role: create(:role, permissions: %w[leads:read]))

    post "/api/leads", params: {lead: {email: "x@example.com"}}, headers: api_headers(reader), as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "is listed in the manifest with the plugin" do
    get "/api/manifest", headers: api_headers

    leads = response.parsed_body["plugins"].find { it["key"] == "leads" }
    expect(leads["endpoints"].map { it["path"] }).to include("/api/leads", "/api/leads/:lead_id/notes")
    expect(response.parsed_body["counts"]).to include("leads" => 0)
  end

  it "offers its events to webhooks" do
    expect(Webhook.events).to include("lead.created", "lead.stage_changed", "lead.qualified", "lead.unsubscribed", "lead_task.created")
  end
end
