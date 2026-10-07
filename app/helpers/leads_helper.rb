# frozen_string_literal: true

# The Leads plugin's screens: stage badges, the timeline's icons, the
# choices its selects offer.
module LeadsHelper
  # A stage's badge color: gray for new, yellow while it's being nurtured,
  # the accent once it's qualified, green for a customer, red for lost.
  LEAD_STAGE_TONES = {"new" => :gray, "nurturing" => :yellow, "qualified" => :blue, "customer" => :green, "lost" => :red}.freeze

  LEAD_ACTIVITY_ICONS = {
    "created" => "person-add", "submitted" => "form",
    "email_sent" => "email", "email_opened" => "eye", "email_clicked" => "link",
    "unsubscribed" => "bell-off", "resubscribed" => "bell",
    "stage_changed" => "arrow-right", "qualified" => "check-circle", "score_changed" => "chart",
    "note" => "comment", "task_created" => "calendar", "task_done" => "check",
    "enrolled" => "megaphone", "enrollment_stopped" => "close-circle", "enrollment_completed" => "check-circle"
  }.freeze

  def lead_stage_badge(stage)
    tag.span stage.to_s.humanize, class: ui(:badge, LEAD_STAGE_TONES.fetch(stage.to_s, :gray))
  end

  def lead_activity_icon(kind)
    icon_tag LEAD_ACTIVITY_ICONS.fetch(kind.to_s, "history"), class: "size-4 text-gray-500"
  end

  def lead_stage_options = Leads::Lead::STAGES.map { [it.humanize, it] }

  # The people a lead or task can be given to.
  def lead_user_options = User.order(:name).map { [it.name, it.id] }

  # "Due today", "3 days overdue", "Due Oct 9" — red when it's late.
  def lead_task_due(task)
    return tag.span("No due date", class: "text-gray-400") if task.due_on.nil?

    days = (task.due_on - Date.current).to_i
    text = if task.done? then "Due #{l(task.due_on, format: :short)}"
    elsif days.negative? then "#{pluralize(-days, "day")} overdue"
    elsif days.zero? then "Due today"
    elsif days == 1 then "Due tomorrow"
    else "Due #{l(task.due_on, format: :short)}"
    end
    tag.span text, class: class_names("whitespace-nowrap", task.overdue? ? "font-medium text-red-600" : "text-gray-500"),
      title: l(task.due_on, format: :long)
  end

  # Forms whose submissions can make leads, with the sequence a new one joins.
  def lead_sequence_options(sequences) = sequences.map { [it.active? ? it.name : "#{it.name} (off)", it.id] }

  def lead_points(points)
    return "" if points.to_i.zero?

    tag.span "#{"+" if points.positive?}#{points}", class: ui(:badge, points.positive? ? :green : :red, "tabular-nums")
  end
end
