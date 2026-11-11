# Brings an install's Leads 2 records (set aside as leads_v2_*) into 3.0: each lead with its owner,
# client and what its forms sent; open ones (new, nurturing, qualified) at the first stage, a
# customer won, lost lost and spam lost as spam; its history as it was; its earliest open follow-up
# as its next step and every follow-up in its history; and the website's capture key as a form, so
# the address the website posts to keeps working. Plain SQL over the tables, no models, so it runs
# whatever the code becomes. Nothing to do on an install that never had 2.
class BringLeadsTwoAcross < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:leads_v2_leads)
    return if select_value("SELECT COUNT(*) FROM leads_leads").to_i.positive?

    first_stage = select_value("SELECT id FROM leads_stages ORDER BY position, id LIMIT 1")
    now = Time.current.utc.iso8601

    execute <<~SQL
      INSERT INTO leads_leads (id, name, email, phone, company, source, details, state, stage_id, owner_id, client_id, lost_reason,
                               closed_at, submissions_count, last_activity_at, created_at, updated_at)
      SELECT id, name, LOWER(email), phone, company, COALESCE(NULLIF(source_label, ''), source), COALESCE(fields, '{}'),
             CASE stage WHEN 'customer' THEN 'won' WHEN 'lost' THEN 'lost' WHEN 'spam' THEN 'lost' ELSE 'open' END,
             CASE WHEN stage IN ('customer', 'lost', 'spam') THEN NULL ELSE #{first_stage.to_i} END,
             owner_id, client_id,
             CASE stage WHEN 'spam' THEN 'spam' ELSE NULL END,
             CASE WHEN stage IN ('customer', 'lost', 'spam') THEN updated_at ELSE NULL END,
             1, last_activity_at, created_at, updated_at
      FROM leads_v2_leads
    SQL

    if table_exists?(:leads_v2_activities)
      execute <<~SQL
        INSERT INTO leads_activities (lead_id, user_id, kind, body, data, created_at)
        SELECT lead_id, user_id, CASE kind WHEN 'note' THEN 'note' ELSE 'earlier' END, body,
               json_object('summary', summary, 'kind', kind), created_at
        FROM leads_v2_activities WHERE lead_id IN (SELECT id FROM leads_leads)
      SQL
    end

    if table_exists?(:leads_tasks)
      execute <<~SQL
        INSERT INTO leads_activities (lead_id, user_id, kind, body, data, created_at)
        SELECT lead_id, creator_id, 'earlier', NULL,
               json_object('summary', 'follow-up: ' || title || COALESCE(', due ' || due_on, '') || CASE WHEN done_at IS NULL THEN '' ELSE ' (done)' END,
                           'kind', 'follow_up'), created_at
        FROM leads_tasks WHERE lead_id IN (SELECT id FROM leads_leads)
      SQL
      execute <<~SQL
        UPDATE leads_leads SET
          next_step = (SELECT title FROM leads_tasks WHERE leads_tasks.lead_id = leads_leads.id AND done_at IS NULL ORDER BY due_on IS NULL, due_on, id LIMIT 1),
          next_step_on = (SELECT due_on FROM leads_tasks WHERE leads_tasks.lead_id = leads_leads.id AND done_at IS NULL ORDER BY due_on IS NULL, due_on, id LIMIT 1)
        WHERE state = 'open'
      SQL
    end

    execute <<~SQL
      INSERT INTO leads_activities (lead_id, kind, data, created_at)
      SELECT id, 'earlier', json_object('summary', 'handed it to Leads 3', 'kind', 'upgrade'), '#{now}' FROM leads_leads
    SQL

    if table_exists?(:leads_v2_settings) && (key = select_value("SELECT capture_key FROM leads_v2_settings ORDER BY id LIMIT 1")).present?
      execute "INSERT INTO leads_capture_keys (name, token, created_at, updated_at) VALUES ('Website forms (from Leads 2)', #{quote(key)}, '#{now}', '#{now}')"
    end
  end

  def down
    execute "DELETE FROM leads_activities"
    execute "DELETE FROM leads_capture_keys"
    execute "DELETE FROM leads_leads"
  end
end
