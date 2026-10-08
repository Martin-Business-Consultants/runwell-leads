json.summary "#{@leads.size} #{@stage == "all" ? "" : "#{@stage} "}#{"lead".pluralize(@leads.size)}"
json.leads @leads do |lead|
  json.merge! agent_ref(lead)
  json.url lead_url(lead)
  json.extract! lead, :email, :name, :company, :phone, :stage, :score, :last_activity_at
  json.source lead.source_text
  json.owner lead.owner&.display_name
  json.unsubscribed lead.unsubscribed?
end
