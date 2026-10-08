json.summary "#{@sequences.size} lead email #{"sequence".pluralize(@sequences.size)}, #{@sequences.count(&:active?)} on"
json.sequences @sequences do |sequence|
  json.extract! sequence, :id, :name, :active, :trigger, :trigger_source, :trigger_stage
  json.starts sequence.trigger_label
  json.emails sequence.steps.size
  json.leads_in_it @counts.fetch(sequence.id, 0)
  json.url leads_sequence_url(sequence)
end
