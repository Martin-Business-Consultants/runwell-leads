leads = @leads || @board.values.flat_map { it[:leads] }
json.summary "#{leads.size} #{@show == "all" ? "" : "#{Leads::LeadsController::SHOWS[@show].downcase} "}#{leads.size == 1 ? "lead" : "leads"}#{" owned by #{@owner}" unless @owner == "anyone"}"
json.leads leads do |lead|
  json.partial! "leads/leads/lead", lead: lead
end
