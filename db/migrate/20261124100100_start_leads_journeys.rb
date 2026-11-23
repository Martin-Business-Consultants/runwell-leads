# Gives an install a plan to start from, and keeps what its leads already had. Templates and a
# plan for each of the stages 3.0 starts with (matched by name, so renamed or deleted ones are
# left alone), only where nobody has made any yet; and each open lead's next step becomes the
# first step of its plan, so nothing planned is lost. Plain SQL, so it runs whatever the code becomes.
class StartLeadsJourneys < ActiveRecord::Migration[8.1]
  TEMPLATES = [
    [ "Book a call", "A quick call?", <<~HTML ],
      <p>Hi {{first_name}},</p><p>Thanks for getting in touch. The quickest way to see whether we can help is a short call: 20 minutes on what you’re after and where you are now.</p><p>Which of these suits you, or send a time that works better?</p><ul><li>…</li><li>…</li></ul><p>{{my_first_name}}</p>
    HTML
    [ "Call recap", "Our call, and what happens next", <<~HTML ],
      <p>Hi {{first_name}},</p><p>Thanks for your time today. Here’s what I heard, so we’re on the same page:</p><ul><li><strong>Where you are now:</strong> …</li><li><strong>What you want:</strong> …</li><li><strong>Timing and budget:</strong> …</li></ul><p><strong>Next:</strong> I’ll send a proposal by …. If I’ve missed anything, just reply.</p><p>{{my_first_name}}</p>
    HTML
    [ "Proposal check-in", "Did the proposal come through?", <<~HTML ],
      <p>Hi {{first_name}},</p><p>Just checking the proposal reached you. Happy to walk through it on a quick call if that’s easier than reading it.</p><p>{{my_first_name}}</p>
    HTML
    [ "Following up", "Any questions on the proposal?", <<~HTML ],
      <p>Hi {{first_name}},</p><p>Following up on the proposal. Is there anything you’d like changed, or anyone else who should see it before you decide?</p><p>{{my_first_name}}</p>
    HTML
    [ "Last nudge", "Should I close this out?", <<~HTML ]
      <p>Hi {{first_name}},</p><p>I haven’t heard back, so I’m guessing the timing isn’t right. Shall I close this out for now? If things change, reply here and we’ll pick it up where we left off.</p><p>{{my_first_name}}</p>
    HTML
  ].freeze

  # Stage name => [ title, days after arriving, template name ]
  PLANS = {
    "New" => [ [ "Reply and book a call", 0, "Book a call" ] ],
    "Call booked" => [ [ "Look them up before the call: their site, goals, competitors", 0, nil ] ],
    "Call held" => [ [ "Send the call recap", 0, "Call recap" ], [ "Send the proposal", 2, nil ] ],
    "Proposal sent" => [ [ "Check the proposal reached them", 2, "Proposal check-in" ], [ "Follow up on the proposal", 5, "Following up" ],
                         [ "Last nudge, or close it out", 12, "Last nudge" ] ]
  }.freeze

  def up
    now = q(Time.current.utc.iso8601)

    if select_value("SELECT COUNT(*) FROM leads_templates").to_i.zero?
      TEMPLATES.each_with_index do |(name, subject, body), index|
        execute "INSERT INTO leads_templates (name, subject, body, position, created_at, updated_at) VALUES (#{q(name)}, #{q(subject)}, #{q(body.squish)}, #{index}, #{now}, #{now})"
      end
    end

    if select_value("SELECT COUNT(*) FROM leads_playbook_steps").to_i.zero?
      PLANS.each do |stage_name, steps|
        stage_id = select_value("SELECT id FROM leads_stages WHERE LOWER(name) = #{q(stage_name.downcase)} LIMIT 1") or next
        steps.each_with_index do |(title, days, template), index|
          template_id = template && select_value("SELECT id FROM leads_templates WHERE name = #{q(template)} LIMIT 1")
          execute "INSERT INTO leads_playbook_steps (stage_id, title, days_after, template_id, position, created_at, updated_at) " \
                  "VALUES (#{stage_id.to_i}, #{q(title)}, #{days}, #{template_id ? template_id.to_i : "NULL"}, #{index}, #{now}, #{now})"
        end
      end
    end

    execute <<~SQL
      INSERT INTO leads_steps (lead_id, title, due_on, created_at, updated_at)
      SELECT id, COALESCE(next_step, 'Follow up'), next_step_on, #{now}, #{now}
      FROM leads_leads
      WHERE state = 'open' AND (next_step IS NOT NULL OR next_step_on IS NOT NULL)
        AND NOT EXISTS (SELECT 1 FROM leads_steps WHERE leads_steps.lead_id = leads_leads.id)
    SQL
  end

  def down; end

  private
    def q(value) = connection.quote(value)
end
