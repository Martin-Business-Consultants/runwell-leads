json.summary "#{@lead.display_name}: #{@lead.stage_label}#{", #{@lead.owner.display_name}’s" if @lead.owner}#{", next: #{@lead.next_step}" if @lead.next_step}#{" by #{@lead.next_step_on}" if @lead.next_step_on}#{", #{@lead.attention_label.downcase}" if @lead.attention}"
json.partial! "leads/leads/lead", lead: @lead
json.message agent_text(@lead.message) if @lead.message.present?
json.extract! @lead, :referrer_name, :referrer_email, :last_submitted_at, :last_activity_at, :closed_at
json.details @lead.details
if (known = @lead.known_contact)
  json.already_a_contact_at agent_ref(known.client)
end
json.plan @steps do |step|
  json.extract! step, :id, :title, :due_on
  json.done step.done?
  json.done_at step.done_at if step.done?
  json.overdue step.overdue?
  json.template_id step.template_id if step.template_id
end
json.people @lead.people do |person|
  json.extract! person, :id, :name, :email, :phone, :title, :role
end
json.files @lead.attachments do |attachment|
  json.id attachment.id
  json.name attachment.display_name
  json.url attachment.link? ? attachment.url : main_app.rails_blob_url(attachment.file)
  json.kind attachment.link? ? "link" : "file"
end
json.history @activities do |activity|
  json.kind activity.kind
  json.by activity.author
  json.what activity.summary(stages: @stage_names, people: @people)
  json.text agent_text(activity.body) if activity.body.present?
  json.at activity.created_at
end
