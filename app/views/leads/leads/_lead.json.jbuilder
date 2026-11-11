json.type "Lead"
json.id lead.id
json.name lead.display_name
json.url lead_url(lead)
json.extract! lead, :name, :email, :phone, :company, :website, :source, :state, :value_cents, :next_step, :next_step_on, :submissions_count, :created_at
json.value lead_value(lead)
json.stage lead.stage && { id: lead.stage_id, name: lead.stage.name }
json.owner lead.owner && { id: lead.owner_id, name: lead.owner.display_name }
json.attention lead.attention
json.lost_reason lead.lost_reason if lead.lost?
json.client agent_ref(lead.client) if lead.client
