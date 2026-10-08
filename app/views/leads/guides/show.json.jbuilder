json.summary @guide.summary
json.extract! @guide, :key, :title, :minutes, :stages
json.text agent_text(render(partial: @guide.partial, formats: :html))
