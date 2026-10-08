json.summary "#{@sequence.name}: #{pluralize(@sequence.steps.size, "email")}, #{@sequence.active? ? "on" : "off"}, #{@enrollments.size} in it"
json.extract! @sequence, :id, :name, :active, :trigger, :trigger_source, :trigger_stage
json.starts @sequence.trigger_label
json.url leads_sequence_url(@sequence)
json.emails @sequence.steps do |step|
  json.extract! step, :id, :subject, :delay_amount, :delay_unit
  json.number step.number
  json.when step.delay_label
  json.body agent_text(step.body)
end
json.leads_in_it @enrollments do |enrollment|
  json.merge! agent_ref(enrollment.lead)
  json.progress enrollment.progress_label
  json.next_send_at enrollment.next_send_at
end
