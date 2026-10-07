# frozen_string_literal: true

json.tasks @tasks do |task|
  json.partial! "api/leads/tasks/task", record: task
  json.lead do
    json.extract! task.lead, :id, :email, :name
  end
end
