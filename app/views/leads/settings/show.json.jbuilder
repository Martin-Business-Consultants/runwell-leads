people = @setting.notified_people
json.summary "#{@stages.size} stages; new leads go to #{@setting.notify_user_ids.any? ? people.map(&:display_name).to_sentence : "every owner and manager"}; #{@keys.size} #{@keys.size == 1 ? "form sends" : "forms send"} leads in"
json.notify_user_ids @setting.notify_user_ids
json.notified people.map { { id: it.id, name: it.display_name } }
json.stages @stages do |stage|
  json.extract! stage, :id, :name, :position
  json.open_leads @open_counts.fetch(stage.id, 0)
end
json.forms @keys do |key|
  json.extract! key, :id, :name, :leads_count, :last_used_at
end
