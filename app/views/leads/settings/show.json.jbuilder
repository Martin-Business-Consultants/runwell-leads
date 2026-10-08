json.summary "Leads qualify at #{@settings.threshold} points; forms post to the capture URL"
json.capture_url leads_capture_url(key: @settings.capture_key)
json.points Leads::Settings::POINTS.keys.index_with { @settings.points_for(it) }
json.threshold @settings.threshold
json.thanks_url @settings.thanks_url
json.form_sources @sources
