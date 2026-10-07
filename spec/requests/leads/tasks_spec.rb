# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe "Leads › Tasks", type: :request do
  let(:admin) { create(:user, name: "Alice") }
  let(:other) { create(:user, name: "Bob") }
  let(:lead) { make_lead }

  before { sign_in_as admin }

  it "lists my open tasks overdue first, everyone's, and the done ones" do
    Leads::Task.assign(lead, {title: "Mine later", due_on: 5.days.from_now.to_date, assignee_id: admin.id})
    Leads::Task.assign(lead, {title: "Mine late", due_on: 1.day.ago.to_date, assignee_id: admin.id})
    Leads::Task.assign(lead, {title: "Bob's", assignee_id: other.id})
    Leads::Task.assign(lead, {title: "Finished", assignee_id: admin.id}).complete

    get leads_tasks_path
    expect(response.body).to include("Mine late", "Mine later")
    expect(response.body.index("Mine late")).to be < response.body.index("Mine later")
    expect(response.body).not_to include("Bob&#39;s", "Finished")

    get leads_tasks_path(view: "all")
    expect(response.body).to include("Bob&#39;s")

    get leads_tasks_path(view: "done")
    expect(response.body).to include("Finished")
  end

  it "ticks a task off, reopens it, edits and deletes it" do
    task = Leads::Task.assign(lead, {title: "Call"})

    post leads_task_completion_path(task)
    expect(task.reload).to be_done

    delete leads_task_completion_path(task)
    expect(task.reload).not_to be_done

    get edit_leads_task_path(task, return_to: "lead")
    expect(response).to have_http_status(:ok)

    patch leads_task_path(task), params: {task: {title: "Call again", due_on: "", assignee_id: other.id}, return_to: "lead"}
    expect(response).to redirect_to(lead_path(lead, anchor: "tasks"))
    expect(task.reload).to have_attributes(title: "Call again", assignee: other)

    delete leads_task_path(task)
    expect(Leads::Task.count).to eq 0
  end

  it "shows my tasks due on the dashboard" do
    Leads::Task.assign(lead, {title: "Due now", due_on: Date.current, assignee_id: admin.id})
    Leads::Task.assign(lead, {title: "Plan the autumn menu", due_on: 7.days.from_now.to_date, assignee_id: admin.id})

    get dashboard_path

    panel = Nokogiri::HTML(response.body).at_css("[aria-labelledby='dashboard_leads_tasks']").text
    expect(panel).to include("Tasks due", "Due now", "Due today")
    expect(panel).not_to include("Plan the autumn menu")
  end
end
