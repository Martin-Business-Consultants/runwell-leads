# frozen_string_literal: true

module Leads
  # Someone who might become a customer: one per email address, gathered
  # from form submissions (Capturable), added by hand or over the API. A lead
  # moves through stages (Staged), earns a score from what it does (Scored),
  # keeps a timeline of everything (Timelined), has follow-up tasks, and can
  # be enrolled in email sequences (Enrollable) until it unsubscribes
  # (Subscribable).
  class Lead < ApplicationRecord
    include ListSearchable

    search_on :email, :name, :company

    include Eventable
    include Timelined
    include Scored
    include Staged
    include Enrollable
    include Subscribable
    include Capturable

    # Its events are "lead.…", in the audit log and to webhooks.
    def self.eventable_prefix = "lead"

    SOURCES = %w[form manual api].freeze

    belongs_to :owner, class_name: "::User", optional: true
    has_many :tasks, class_name: "Leads::Task", dependent: :delete_all
    has_many :messages, class_name: "Leads::Message", dependent: :delete_all

    normalizes :email, with: -> { it.to_s.strip.downcase }

    validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}
    validates :source, inclusion: {in: SOURCES}
    validates :stage, inclusion: {in: STAGES}

    scope :recent_first, -> { order(Arel.sql("COALESCE(leads_leads.last_activity_at, leads_leads.created_at) DESC"), id: :desc) }

    def display_name = name.presence || email

    # The form it first came from, while that form exists.
    def source_form
      Form.with_discarded.find_by(id: source_form_id) if source_form_id && defined?(::Form)
    end

    def source_label
      case source
      when "form" then "Form: #{source_form&.title || "deleted form"}"
      when "api" then "API"
      else "Added by hand"
      end
    end

    # Recorded first, so the audit row names the lead as it was; its
    # activities, tasks, enrollments and messages go with it.
    def forget
      track_event(:deleted, email: email)
      destroy!
    end

    def self.forget_all(leads)
      leads = leads.to_a
      track_event(:bulk_deleted, emails: leads.map(&:email)) if leads.any?
      leads.each(&:destroy!)
      leads
    end

    # What webhooks receive (lead.created, lead.stage_changed, lead.qualified,
    # lead.unsubscribed).
    def webhook_payload
      {
        id:              id,
        email:           email,
        name:            name,
        phone:           phone,
        company:         company,
        stage:           stage,
        score:           score,
        source:          source,
        source_form:     source_form&.slug,
        owner_email:     owner&.email,
        unsubscribed:    unsubscribed?,
        fields:          fields,
        created_at:      created_at&.iso8601,
        updated_at:      updated_at&.iso8601
      }
    end
  end
end
