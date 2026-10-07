# frozen_string_literal: true

json.extract! record, :id, :kind, :summary, :body, :points, :data
json.user record.user&.email
json.created_at record.created_at.iso8601
