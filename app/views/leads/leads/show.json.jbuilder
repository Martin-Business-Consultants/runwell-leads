json.merge! agent_ref(@lead)
json.url lead_url(@lead)
json.summary "#{@lead.display_name}: #{@lead.stage}, score #{@lead.score}, #{pluralize(@tasks.count { !it.done? }, "open task")}"
json.extract! @lead, :email, :name, :phone, :company, :stage, :score, :created_at, :last_activity_at
json.source @lead.source_text
json.owner @lead.owner&.display_name
json.unsubscribed @lead.unsubscribed?
json.client(@lead.client && agent_ref(@lead.client))
json.fields @lead.fields
json.tasks @tasks do |task|
  json.extract! task, :id, :title, :due_on
  json.done task.done?
  json.assignee task.assignee&.display_name
end
json.sequences @enrollments do |enrollment|
  json.extract! enrollment, :id, :status, :next_send_at, :stop_reason
  json.sequence enrollment.sequence.name
  json.progress enrollment.progress_label
end
json.timeline @activities do |activity|
  json.extract! activity, :kind, :summary, :points, :created_at
  json.body agent_text(activity.body) if activity.note?
  json.by activity.user&.display_name
end
