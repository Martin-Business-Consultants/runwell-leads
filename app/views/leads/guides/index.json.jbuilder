json.summary "#{@guides.size} sales guides"
json.guides @guides do |guide|
  json.extract! guide, :key, :title, :summary, :minutes, :stages
  json.url leads_guide_url(guide)
end
