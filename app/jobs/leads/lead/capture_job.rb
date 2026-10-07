# frozen_string_literal: true

# A form submission becoming (or updating) its lead (Leads::Lead::Capturable).
class Leads::Lead::CaptureJob < ApplicationJob
  queue_as :default

  def perform(submission_id)
    submission = FormSubmission.find_by(id: submission_id) or return

    Leads::Lead.capture_now(submission)
  end
end
