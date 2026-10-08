json.summary(@response&.ready? ? "Replies drafted #{time_ago_in_words(@response.created_at)} ago: #{@response.summary}" : (@response&.working? ? "Still drafting" : "No replies drafted yet"))
json.state @response&.state
json.drafted_at @response&.created_at
json.lead do
  json.merge! agent_ref(@lead)
  json.url lead_url(@lead)
end
json.replies(@response&.ready? ? @response.payload : nil)
json.error @response&.error if @response&.failed?
