# frozen_string_literal: true

json.partial! "api/leads/leads/summary", record: @lead
json.fields @lead.fields
json.activities @lead.activities.includes(:user).limit(100) do |activity|
  json.partial! "api/leads/activities/activity", record: activity
end
json.tasks @lead.tasks.includes(:assignee).in_due_order do |task|
  json.partial! "api/leads/tasks/task", record: task
end
json.enrollments @lead.enrollments.includes(sequence: :steps).newest_first do |enrollment|
  json.partial! "api/leads/enrollments/enrollment", record: enrollment
end
