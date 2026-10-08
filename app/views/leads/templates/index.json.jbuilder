json.summary "#{@templates.size} reply #{"template".pluralize(@templates.size)}"
json.templates @templates do |template|
  json.extract! template, :id, :kind, :title, :situation, :subject
  json.body agent_text(template.body)
end
