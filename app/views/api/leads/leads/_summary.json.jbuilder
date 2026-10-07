# frozen_string_literal: true

json.extract! record, :id, :email, :name, :phone, :company, :stage, :score, :source
json.source_form record.source_form&.slug
json.owner record.owner && {id: record.owner.id, name: record.owner.name, email: record.owner.email}
json.unsubscribed_at record.unsubscribed_at&.iso8601
json.last_activity_at record.last_activity_at&.iso8601
json.created_at record.created_at.iso8601
json.updated_at record.updated_at.iso8601
