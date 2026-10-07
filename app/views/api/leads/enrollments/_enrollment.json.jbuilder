# frozen_string_literal: true

json.extract! record, :id, :sequence_id, :status, :current_step
json.sequence record.sequence.name
json.steps record.sequence.steps.size
json.next_send_at record.next_send_at&.iso8601
json.last_sent_at record.last_sent_at&.iso8601
json.finished_at record.finished_at&.iso8601
json.stop_reason record.stop_reason
json.created_at record.created_at.iso8601
