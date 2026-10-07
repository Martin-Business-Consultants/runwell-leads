# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe "Leads admin", type: :request do
  let(:admin) { create(:user, name: "Alice") }

  before { sign_in_as admin }

  describe "the list" do
    it "shows a tab per stage with counts, and the leads in the chosen one" do
      make_lead("a@example.com", name: "Ada", stage: "qualified", score: 60)
      make_lead("b@example.com", name: "Bo")

      get leads_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ada", "Bo", "Qualified", "Set to lost")

      get leads_path(stage: "qualified")
      expect(response.body).to include("Ada")
      expect(response.body).not_to include("b@example.com")
    end

    it "searches by email, name or company" do
      make_lead("a@example.com", name: "Ada", company: "Mill Co")
      make_lead("b@example.com", name: "Bo")

      get leads_path(s: "mill")

      expect(response.body).to include("Ada")
      expect(response.body).not_to include("b@example.com")
    end

    it "changes the stage of the ticked leads, and deletes them" do
      ada = make_lead("a@example.com")
      bo = make_lead("b@example.com")

      post leads_bulk_stage_changes_path, params: {status: "lost", ids: [ada.id, bo.id]}
      expect(response).to redirect_to(leads_path)
      expect([ada.reload.stage, bo.reload.stage]).to eq %w[lost lost]

      post leads_bulk_deletions_path, params: {ids: [ada.id]}
      expect(Leads::Lead.pluck(:email)).to eq ["b@example.com"]
    end
  end

  describe "a lead" do
    let(:lead) { make_lead(company: "Mill Co") }

    it "shows its details, timeline, score, tasks and sequences" do
      lead.add_note("Wants a tasting menu")
      Leads::Task.assign(lead, {title: "Send the menu", due_on: Date.yesterday, assignee_id: admin.id})

      get lead_path(lead)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sam Lee", "Mill Co", "Wants a tasting menu", "Send the menu", "1 day overdue", "Not in a sequence")
    end

    it "saves its details, stage and owner from one form" do
      patch lead_path(lead), params: {lead: {name: "Sam Lee-Park", stage: "qualified", owner_id: admin.id}}

      expect(response).to redirect_to(lead_path(lead))
      expect(lead.reload).to have_attributes(name: "Sam Lee-Park", stage: "qualified", owner: admin)
      expect(lead.activities.first.user).to eq admin
    end

    it "shows what's wrong when the details don't save" do
      patch lead_path(lead), params: {lead: {email: "nope"}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Email is invalid")
    end

    it "adds a note, a task, a score adjustment and an enrollment, and stops it" do
      sequence = make_sequence

      post lead_notes_path(lead), params: {note: {body: "Called, keen"}}
      post lead_tasks_path(lead), params: {task: {title: "Follow up", due_on: Date.tomorrow.iso8601, assignee_id: admin.id}}
      post lead_score_adjustments_path(lead), params: {score_adjustment: {points: "7", reason: "Came in"}}
      post lead_enrollments_path(lead), params: {enrollment: {sequence_id: sequence.id}}

      expect(lead.reload).to have_attributes(score: 7, stage: "nurturing")
      expect(lead.tasks.sole).to have_attributes(title: "Follow up", assignee: admin, creator: admin)
      expect(lead.activities.map(&:kind)).to include("note", "task_created", "score_changed", "enrolled")

      enrollment = lead.enrollments.sole
      patch lead_enrollment_path(lead, enrollment)
      expect(enrollment.reload.status).to eq "stopped"
    end

    it "says why a lead can't be enrolled" do
      lead.unsubscribe

      post lead_enrollments_path(lead), params: {enrollment: {sequence_id: make_sequence.id}}

      expect(flash[:alert]).to include("unsubscribed")
    end

    it "adds a lead by hand" do
      post leads_path, params: {lead: {email: "new@example.com", name: "New", stage: "new", owner_id: admin.id}}

      lead = Leads::Lead.find_by!(email: "new@example.com")
      expect(response).to redirect_to(lead_path(lead))
      expect(lead).to have_attributes(source: "manual", owner: admin)
      expect(lead.activities.sole.summary).to eq "Added by Alice"
    end

    it "deletes a lead with everything it holds" do
      lead.add_note("x")

      delete lead_path(lead)

      expect(response).to redirect_to(leads_path)
      expect(Leads::Activity.count).to eq 0
    end
  end

  describe "permissions and the plugin switch" do
    it "lets a role without leads:read in nowhere" do
      sign_in_as create(:user, admin: false, role: create(:role, permissions: %w[pages:read]))

      get leads_path

      expect(response).to redirect_to(dashboard_path)
    end

    it "lets a reader look but not change" do
      sign_in_as create(:user, admin: false, role: create(:role, permissions: %w[leads:read]))
      lead = make_lead

      get lead_path(lead)
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("Add note")

      patch lead_path(lead), params: {lead: {name: "Changed"}}
      expect(lead.reload.name).to eq "Sam Lee"
    end

    it "is a 404 while the plugin is off, and leaves the menu" do
      switch_plugin :leads, on: false

      get leads_path
      expect(response).to have_http_status(:not_found)

      get dashboard_path
      expect(response.body).not_to include(leads_path)
    end

    it "is in the admin menu, the + New menu and the dashboard while it's on" do
      get dashboard_path

      expect(response.body).to include(leads_path, new_lead_path, "Tasks due")
    end
  end
end
