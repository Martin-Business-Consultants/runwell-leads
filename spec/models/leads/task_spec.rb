# frozen_string_literal: true

require "rails_helper"
require Leads::Engine.root.join("spec/support/leads_helpers")

RSpec.describe Leads::Task do
  let(:lead) { make_lead }
  let(:user) { create(:user) }

  it "is assigned on a lead's timeline and announced" do
    announced = []
    subscriber = ActiveSupport::Notifications.subscribe("lead_task.created.cms") { announced << it.payload[:data][:title] }

    task = Leads::Task.assign(lead, {title: "Call back", due_on: Date.tomorrow, assignee_id: user.id}, user: user)

    expect(task).to be_persisted
    expect(task.creator).to eq user
    expect(lead.activities.sole).to have_attributes(kind: "task_created", summary: "Task added: Call back")
    expect(announced).to eq ["Call back"]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  it "is done once, on the timeline, and can be reopened" do
    task = Leads::Task.assign(lead, {title: "Call back"})

    expect(task.complete).to be true
    expect(task.complete).to be false
    expect(lead.activities.first.kind).to eq "task_done"
    expect(task.reopen).to be true
    expect(task).not_to be_done
  end

  it "lists overdue first, then by due date, undated last" do
    later = Leads::Task.assign(lead, {title: "Later", due_on: 3.days.from_now.to_date})
    undated = Leads::Task.assign(lead, {title: "Whenever"})
    overdue = Leads::Task.assign(lead, {title: "Late", due_on: 2.days.ago.to_date})

    expect(Leads::Task.pending.in_due_order).to eq [overdue, later, undated]
    expect(Leads::Task.overdue).to eq [overdue]
    expect(overdue).to be_overdue
  end
end
