module Leads
  # Someone who might become a client: one per email address, captured from a website's form
  # (Capturable), added by hand or by an agent. A lead moves through stages (Staged), earns a score
  # from what it does (Scored), keeps a timeline of everything (Timelined), has follow-up tasks,
  # can be sent email sequences (Enrollable) until it unsubscribes (Subscribable), and becomes a
  # client in one step (Convertible).
  class Lead < ApplicationRecord
    include Timelined, Scored, Staged, Enrollable, Subscribable, Capturable, Convertible

    SOURCES = %w[website manual agent].freeze

    belongs_to :owner, class_name: "::User", optional: true
    belongs_to :client, class_name: "::Client", optional: true
    has_many :tasks, class_name: "Leads::Task", dependent: :delete_all
    has_many :messages, class_name: "Leads::Message", dependent: :delete_all

    normalizes :email, with: -> { it.to_s.strip.downcase }

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :source, inclusion: { in: SOURCES }
    validates :stage, inclusion: { in: STAGES }

    scope :recent_first, -> { order(Arel.sql("COALESCE(leads_leads.last_activity_at, leads_leads.created_at) DESC"), id: :desc) }
    scope :matching, ->(terms) {
      pattern = "%#{sanitize_sql_like(terms.to_s.strip.downcase)}%"
      where("LOWER(leads_leads.email) LIKE :p OR LOWER(leads_leads.name) LIKE :p OR LOWER(leads_leads.company) LIKE :p", p: pattern)
    }

    def display_name = name.presence || email
    def label = display_name

    def source_text
      case source
      when "website" then source_label.presence || "Website"
      when "agent" then "Added by an agent"
      else "Added by hand"
      end
    end

    # A lead someone added (or an agent did): its first activity, and the sequences its stage starts.
    def record_creation(user: Current.user)
      record_activity(:created, summary: source == "agent" ? "Added by #{user&.display_name || "an agent"}" : "Added by #{user&.display_name || "hand"}", user: user)
      enroll_in_sequences_for_stage unless stage == "new"
    end
  end
end
