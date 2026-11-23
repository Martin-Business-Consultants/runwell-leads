people = @setting.notified_people
json.summary "#{@stages.size} stages, #{@plans.values.sum(&:size)} planned steps, #{@templates.size} templates; morning email #{@setting.digest_label}; new leads go to #{@setting.notify_user_ids.any? ? people.map(&:display_name).to_sentence : "every owner and manager"}; #{@keys.size} #{@keys.size == 1 ? "form sends" : "forms send"} leads in"
json.notify_user_ids @setting.notify_user_ids
json.notified people.map { { id: it.id, name: it.display_name } }
json.digest_hour @setting.digest_hour
json.cold_after_days @setting.cold_after_days
json.stages @stages do |stage|
  json.extract! stage, :id, :name, :position
  json.open_leads @open_counts.fetch(stage.id, 0)
  json.plan @plans.fetch(stage.id, []) do |step|
    json.extract! step, :id, :title, :days_after, :template_id
  end
end
json.templates @templates do |template|
  json.extract! template, :id, :name, :subject
  json.body agent_text(template.body) if template.body.present?
end
json.forms @keys do |key|
  json.extract! key, :id, :name, :leads_count, :last_used_at
end
