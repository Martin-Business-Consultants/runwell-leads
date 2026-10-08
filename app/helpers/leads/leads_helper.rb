# The Leads plugin's screens: stage tags, the timeline's icons, the choices its selects offer.
module Leads::LeadsHelper
  # A stage's tone in the core's status palette.
  LEAD_STAGE_TONES = { "new" => "waiting", "nurturing" => "progress", "qualified" => "positive", "customer" => "positive", "lost" => "neutral" }.freeze

  LEAD_ACTIVITY_ICONS = {
    "created" => "person-add", "captured" => "globe",
    "email_sent" => "email", "email_opened" => "eye", "email_clicked" => "arrow-right",
    "unsubscribed" => "bell-off", "resubscribed" => "bell",
    "stage_changed" => "move", "qualified" => "check-circle", "score_changed" => "bolt",
    "note" => "comment", "task_created" => "pinned", "task_done" => "check",
    "enrolled" => "email", "enrollment_stopped" => "remove", "enrollment_completed" => "check-circle",
    "converted" => "check-circle"
  }.freeze

  def lead_stage_tag(stage)
    tag.span stage.to_s.humanize, class: "status-tag status-tag--#{LEAD_STAGE_TONES.fetch(stage.to_s, "neutral")} txt-nowrap"
  end

  def lead_activity_icon(kind) = icon_tag(LEAD_ACTIVITY_ICONS.fetch(kind.to_s, "history"))

  def lead_stage_options = Leads::Lead::STAGES.map { [ it.humanize, it ] }

  # The people a lead or task can be given to.
  def lead_people_options = User.active.people.ordered.map { [ it.display_name, it.id ] }

  def lead_owner_filter_options
    [ [ "Anyone’s", "" ], [ "Mine", "me" ] ] + User.active.people.ordered.map { [ it.display_name, it.id.to_s ] }
  end

  # "Due today", "3 days overdue", "Due Oct 9".
  def lead_task_due(task)
    return "No date" if task.due_on.nil?

    days = (task.due_on - Date.current).to_i
    if task.done? then "Due #{l(task.due_on, format: :short)}"
    elsif days.negative? then "#{pluralize(-days, "day")} overdue"
    elsif days.zero? then "Due today"
    elsif days == 1 then "Due tomorrow"
    else "Due #{l(task.due_on, format: :short)}"
    end
  end

  def lead_points(points) = points.to_i.zero? ? nil : "#{"+" if points.positive?}#{points}"

  # Settings › Leads' examples of a website sending leads in.
  def leads_capture_form_snippet(url)
    <<~HTML
      <form action="#{url}" method="post">
        <input type="hidden" name="source" value="Contact page">
        <input type="hidden" name="redirect_to" value="https://example.com/thanks">
        <input name="name" placeholder="Your name">
        <input name="email" type="email" placeholder="Email" required>
        <input name="phone" placeholder="Phone">
        <textarea name="message" placeholder="How can we help?"></textarea>
        <input name="website_url" tabindex="-1" autocomplete="off" hidden>
        <button type="submit">Send</button>
      </form>
    HTML
  end

  def leads_capture_fetch_snippet(url)
    <<~JS
      await fetch("#{url}", {
        method: "POST",
        headers: { "Content-Type": "application/json", "Accept": "application/json" },
        body: JSON.stringify({ email, name, source: "Newsletter signup" })
      }) // 201 { ok: true }, or 422 { ok: false, error } without an email
    JS
  end

  # The plugin's own pages, in a sidebar beside the page.
  def leads_section_nav(current)
    section_nav "Leads" do
      safe_join([
        section_nav_heading("Leads"),
        section_nav_link("All leads", leads_path, icon: "person", current: current == :leads),
        section_nav_link("Follow-ups", leads_tasks_path, icon: "pinned", current: current == :tasks),
        section_nav_link("Email sequences", leads_sequences_path, icon: "email", current: current == :sequences),
        (section_nav_link("Settings", leads_settings_path, icon: "settings", current: current == :settings) if can?(:manage_settings))
      ].compact)
    end
  end
end
