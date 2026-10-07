# frozen_string_literal: true

# Where leads come from. Every form submission with an email address creates
# the lead for that address or updates it (Settings › Leads can switch a form
# off), with a "submitted" activity worth the submission's points; a new
# lead joins the sequence its form names there, and any lead joins the active
# sequences triggered by that form. Leads added by hand or over the API
# start their timeline the same way.
module Leads::Lead::Capturable
  extend ActiveSupport::Concern

  class_methods do
    # Queued for each submission.created (lib/leads/engine.rb), so a visitor's
    # submission never waits on, or fails because of, the leads.
    def capture_later(submission_id)
      Leads::Lead::CaptureJob.perform_later(submission_id)
    end

    # The lead the submission made or updated, or nil when its form isn't
    # captured or it carries no email address.
    def capture_now(submission)
      settings = Leads::Settings.current
      form = submission.form
      return nil unless form && settings.capture?(form)

      submitted = Leads::Lead::SubmittedFields.new(submission)
      return nil unless submitted.email

      lead, created = absorb(submitted, form)
      lead.announce("lead.created") if created
      lead.record_activity(:submitted, summary: "Submitted #{form.title}", user: nil,
        points: settings.points_for(:submission), data: {form: form.slug, submission_id: submission.id})
      if created && (sequence = settings.sequence_for(form))
        lead.enroll(sequence, user: nil)
      end
      lead.enroll_in_triggered(Leads::Sequence.active.triggered_by_form(form))
      lead
    end

    private

    # The lead for the address, with what the submission says filled in.
    # Returns [lead, created?].
    def absorb(submitted, form)
      lead = find_or_initialize_by(email: submitted.email)
      created = lead.new_record?
      lead.assign_attributes(submitted.details)
      lead.fields = submitted.data
      lead.assign_attributes(source: "form", source_form_id: form.id) if created
      lead.save!
      [lead, created]
    rescue ActiveRecord::RecordNotUnique
      retry
    end
  end

  # A lead someone added (source "manual") or the API created ("api"): its
  # first activity, the audit row and lead.created.
  def record_creation(user: Current.user)
    record_activity(:created, summary: source == "api" ? "Added through the API" : "Added by #{user&.name || "hand"}", user: user)
    track_event(:created, email: email, source: source)
    announce("lead.created")
    enroll_in_sequences_for_stage unless stage == "new"
  end
end
