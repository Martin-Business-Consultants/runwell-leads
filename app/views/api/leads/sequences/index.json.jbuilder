# frozen_string_literal: true

json.sequences @sequences do |sequence|
  json.extract! sequence, :id, :name, :active, :trigger
  json.trigger_form sequence.trigger_form&.slug
  json.trigger_stage sequence.trigger_stage
  json.steps sequence.steps do |step|
    json.extract! step, :id, :position, :delay_amount, :delay_unit, :subject, :body
  end
end
