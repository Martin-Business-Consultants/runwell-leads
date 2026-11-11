module Leads
  # Someone who might buy, from their first form to a sale: who they are, where they came from
  # (source and the form's details: campaign, landing page, referrer), which stage they're at, who
  # owns them and what happens next. Open until it's won (a client is made from it, Lead#win!) or
  # lost (with a reason); a lost lead can be reopened, a won one stays won. Nothing reaches the
  # core's clients until it's won.
  #
  # Every change worth knowing records an Activity (its owner, stage and next step, by whoever made
  # it, Current.user), so its history reads the same whether a person, the board, the bulk bar or
  # an agent made it.
  class Lead < ApplicationRecord
    self.table_name = "leads_leads"

    STATES = %w[open won lost].freeze
    LOST_REASONS = {
      "not_a_fit" => "Not a fit", "no_budget" => "No budget", "went_quiet" => "Went quiet",
      "chose_someone_else" => "Chose someone else", "not_now" => "Not now", "spam" => "Spam"
    }.freeze
    # Words in the page filter (/) match these.
    TEXT_COLUMNS = %w[name email company phone website source message next_step].freeze

    # A move the lead's state doesn't allow, in words a person or an agent can act on.
    class Refused < StandardError; end

    belongs_to :stage, class_name: "Leads::Stage", optional: true
    belongs_to :owner, class_name: "User", optional: true
    belongs_to :created_by, class_name: "User", optional: true
    belongs_to :client, optional: true
    has_many :activities, -> { order(created_at: :desc, id: :desc) }, class_name: "Leads::Activity", dependent: :delete_all

    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }
    normalizes :name, :company, :phone, :website, :source, :next_step, with: ->(value) { value.to_s.squish.presence }

    validates :state, inclusion: { in: STATES }
    validates :lost_reason, inclusion: { in: LOST_REASONS.keys }, allow_nil: true
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validates :value_cents, numericality: { greater_than_or_equal_to: 0, only_integer: true }, allow_nil: true
    validate :someone_to_call
    validate :owner_on_the_team

    before_validation { self.stage ||= Stage.first_stage if open? }
    after_create :log_creation
    after_create_commit :announce
    after_update :record_changes

    scope :open, -> { where(state: "open") }
    scope :won, -> { where(state: "won") }
    scope :lost, -> { where(state: "lost") }
    scope :newest, -> { order(created_at: :desc, id: :desc) }
    scope :unassigned, -> { where(owner_id: nil) }
    scope :owned_by, ->(user) { where(owner_id: user) }
    # Open, past their first stage, with no next step; or a next step whose date has gone.
    scope :needing_attention, -> {
      first = Leads::PerRequest.first_stage_id
      open.where(next_step_on: ...Date.current).or(open.where(next_step_on: nil).where.not(stage_id: first))
    }

    # Every word typed in the page filter appears in one of TEXT_COLUMNS (Runwell's paginate).
    def self.filter_text(query)
      query.to_s.split.first(6).reduce(all) do |scope, word|
        pattern = "%#{sanitize_sql_like(word.downcase)}%"
        scope.where(TEXT_COLUMNS.map { "LOWER(COALESCE(leads_leads.#{it}, '')) LIKE :pattern" }.join(" OR "), pattern: pattern)
      end
    end

    def self.sources = where.not(source: nil).distinct.order(:source).pluck(:source)

    STATES.each { |state| define_method(:"#{state}?") { self.state == state } }

    def display_name = name.presence || company.presence || email.presence || "Lead ##{id}"
    def lost_reason_label = LOST_REASONS[lost_reason]
    def state_label = lost? ? "Lost: #{lost_reason_label || "no reason"}" : state.humanize
    def stage_label = open? ? stage&.name : state_label
    def referral? = referrer_name.present? || referrer_email.present?

    # Whether it needs someone: :overdue (its next step's date has gone) or :no_next_step (open,
    # past its first stage, with nothing planned). Nil when it's fine.
    def attention
      return unless open?
      return :overdue if next_step_on && next_step_on < Date.current
      return :no_next_step if next_step.blank? && next_step_on.nil? && stage_id != Leads::PerRequest.first_stage_id

      nil
    end

    def attention_label = { overdue: "Overdue", no_next_step: "No next step" }[attention]

    # Someone already on file with this address: a client's person. Shown on the lead, so nobody
    # sells to an existing client as a stranger.
    def known_contact = (@known_contact ||= [ (Contact.includes(:client).find_by(email_address: email) if email) ]).first

    def claim!(user)
      raise Refused, "It’s #{state}: reopen it first." unless open?
      raise Refused, "#{owner.display_name} has it already." if owner && owner != user

      update!(owner: user) unless owner == user
    end

    def move_to!(stage)
      raise Refused, "It’s #{state}: reopen it to move it." unless open?

      update!(stage: stage) unless self.stage == stage
    end

    def lose!(reason:, note: nil, by: Current.user)
      raise Refused, "It’s #{state} already." unless open?
      raise Refused, "Say why: #{LOST_REASONS.values.to_sentence(last_word_connector: " or ")}." unless LOST_REASONS.key?(reason.to_s)

      transaction do
        update_columns(state: "lost", lost_reason: reason.to_s, closed_at: Time.current, updated_at: Time.current)
        log!("lost", by: by, body: note.presence, data: { reason: reason.to_s })
      end
    end

    def reopen!(by: Current.user, stage: nil)
      raise Refused, "It’s open." if open?
      raise Refused, "It’s won: #{client&.name || "its client"} is a client now." if won?

      transaction do
        update_columns(state: "open", lost_reason: nil, closed_at: nil, stage_id: (stage || self.stage || Stage.first_stage)&.id, updated_at: Time.current)
        log!("reopened", by: by)
      end
    end

    # A client from it (or an existing one), with its person as a contact unless they're on file
    # already, and a first piece of work when a type is given: Leads::Win does the making.
    def win!(by: Current.user, **options)
      raise Refused, "It’s #{state} already." unless open?

      Win.new(self, by: by, **options).call
    end

    # Something that happened to it, for its history. Logged by a person (a call, a note) or
    # recorded by the change itself.
    def log!(kind, by: Current.user, body: nil, data: {})
      activity = activities.create!(kind: kind, user: by, body: body, data: data)
      update_columns(last_activity_at: activity.created_at) if Activity::LOGGED.key?(kind)
      activity
    end

    private
      def someone_to_call
        errors.add(:base, "Give a name, an email or a company") if name.blank? && email.blank? && company.blank?
      end

      def owner_on_the_team
        errors.add(:owner, "must be someone on the team") if owner && !(owner.staff? && !owner.agent? && owner.active?)
      end

      def log_creation = log!("created", by: created_by, data: { source: source }.compact)
      def announce = Leads::Mailer.notify_new(self)

      def record_changes
        by = Current.user
        if saved_change_to_owner_id?
          log!("owner", by: by, data: { from: owner_id_before_last_save, to: owner_id })
          Leads::Mailer.with(lead: self, user: owner, by: by).assigned.deliver_later if owner && owner != by&.person
        end
        log!("stage", by: by, data: { from: stage_id_before_last_save, to: stage_id }) if saved_change_to_stage_id? && stage_id_before_last_save
        if saved_change_to_next_step? || saved_change_to_next_step_on?
          log!("next_step", by: by, data: { step: next_step, on: next_step_on&.iso8601 })
        end
        log!("value", by: by, data: { cents: value_cents }) if saved_change_to_value_cents?
      end
  end
end
