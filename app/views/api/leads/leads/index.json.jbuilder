# frozen_string_literal: true

json.leads @leads do |lead|
  json.partial! "api/leads/leads/summary", record: lead
end
json.page @page_number
json.per @per
json.total @total
