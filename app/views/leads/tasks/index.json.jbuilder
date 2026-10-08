json.summary "#{@tasks.size} #{@show == "done" ? "done" : "open"} #{"follow-up".pluralize(@tasks.size)}#{" of yours" if @show == "mine"}"
json.tasks @tasks do |task|
  json.extract! task, :id, :title, :due_on, :done_at
  json.overdue task.overdue?
  json.assignee task.assignee&.display_name
  json.lead do
    json.merge! agent_ref(task.lead)
    json.url lead_url(task.lead)
  end
end
