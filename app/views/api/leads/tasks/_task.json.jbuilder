# frozen_string_literal: true

json.extract! record, :id, :lead_id, :title
json.due_on record.due_on&.iso8601
json.overdue record.overdue?
json.assignee record.assignee && {id: record.assignee.id, name: record.assignee.name, email: record.assignee.email}
json.done_at record.done_at&.iso8601
json.created_at record.created_at.iso8601
