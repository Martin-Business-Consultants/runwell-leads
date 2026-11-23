json.summary "Email #{@lead.display_name}#{" from #{@template.name}" if @template}: edit the subject and body, then send_lead_email"
json.lead agent_ref(@lead)
json.recipients @recipients do |person|
  json.extract! person, :name, :email
end
json.to @to
json.step_id @step&.id
json.template_id @template&.id
json.subject @subject
json.body @body
json.templates @templates do |template|
  json.extract! template, :id, :name, :subject
end
