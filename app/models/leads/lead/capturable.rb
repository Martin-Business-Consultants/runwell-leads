# Leads from a website: a form posts to the capture endpoint (Leads::CapturesController) with the
# install's key, and the address it gives becomes a lead or updates the one it already is, with a
# "came in" activity worth the capture points. Any lead that comes in joins the active sequences
# triggered by its source (or by any source).
module Leads::Lead::Capturable
  extend ActiveSupport::Concern

  class_methods do
    # The lead the submission made or updated, or nil when it carries no usable email address.
    def capture(params)
      submission = Leads::Lead::Submission.new(params)
      return nil unless submission.email

      lead, created = absorb(submission)
      source = submission.source.presence || "website"
      lead.record_activity(:captured, summary: "Came in from #{source}", user: nil,
        points: Leads::Settings.current.points_for(:capture), data: { source: source, fields: submission.fields })
      lead.enroll_in_triggered(Leads::Sequence.active.triggered_by_capture(submission.source))
      lead
    end

    private
      # The lead for the address, with what the submission says filled in. Returns [lead, created?].
      def absorb(submission)
        lead = find_or_initialize_by(email: submission.email)
        created = lead.new_record?
        lead.assign_attributes(submission.details)
        lead.fields = lead.fields.to_h.merge(submission.fields)
        lead.assign_attributes(source: "website", source_label: submission.source) if created
        lead.save!
        [ lead, created ]
      rescue ActiveRecord::RecordNotUnique
        retry
      end
  end
end
