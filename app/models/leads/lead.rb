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
  #
  # Its journey (3.1): arriving at a stage lays out that stage's plan as steps, each due some days
  # on (lay_out_plan!); its next step is always its earliest open step (sync_next_step!); and one
  # nobody has been in touch with for Setting#cold_after_days is going cold.
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
    has_many :steps, class_name: "Leads::Step", dependent: :delete_all
    has_many :people, -> { order(:id) }, class_name: "Leads::Person", dependent: :delete_all
    has_many :attachments, -> { newest }, class_name: "Leads::Attachment", dependent: :destroy

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
    after_create { lay_out_plan!(stage, by: created_by) if stage }
    after_create_commit :announce
    after_update :record_changes
    after_update { lay_out_plan!(stage, by: Current.user) if saved_change_to_stage_id? && open? && stage }

    scope :open, -> { where(state: "open") }
    scope :won, -> { where(state: "won") }
    scope :lost, -> { where(state: "lost") }
    scope :newest, -> { order(created_at: :desc, id: :desc) }
    scope :unassigned, -> { where(owner_id: nil) }
    scope :owned_by, ->(user) { where(owner_id: user) }
    # Open, past their first stage, with no next step; or a next step whose date has gone; or nobody
    # in touch for Setting#cold_after_days.
    scope :needing_attention, -> {
      first = Leads::PerRequest.first_stage_id
      scope = open.where(next_step_on: ...Date.current).or(open.where(next_step_on: nil).where.not(stage_id: first))
      (cutoff = Lead.cold_cutoff) ? scope.or(open.where("COALESCE(leads_leads.last_activity_at, leads_leads.created_at) < ?", cutoff)) : scope
    }
    # Open, with a next step due today or gone.
    scope :due_now, -> { open.where(next_step_on: ..Date.current) }
    scope :going_cold, -> { (cutoff = Lead.cold_cutoff) ? open.where("COALESCE(leads_leads.last_activity_at, leads_leads.created_at) < ?", cutoff) : none }

    # Before this, nobody's been in touch long enough for it to be going cold; nil when that's off.
    def self.cold_cutoff = Leads::PerRequest.cold_after_days&.days&.ago

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

    # Whether it needs someone: :overdue (its next step's date has gone), :no_next_step (open, past
    # its first stage, with nothing planned) or :going_cold (nobody in touch for a while). Nil when
    # it's fine.
    def attention
      return unless open?
      return :overdue if next_step_on && next_step_on < Date.current
      return :no_next_step if next_step.blank? && next_step_on.nil? && stage_id != Leads::PerRequest.first_stage_id
      return :going_cold if (cutoff = Lead.cold_cutoff) && last_touch_at < cutoff

      nil
    end

    def attention_label = { overdue: "Overdue", no_next_step: "No next step", going_cold: "Going cold" }[attention]

    # When someone was last in touch (a call, an email, a meeting, a note, a step done), else when it came in.
    def last_touch_at = last_activity_at || created_at

    # Its first person (the lead's own name and email) and anyone else at the business, those with
    # an email, for writing to.
    def recipients
      first = Person.new(name: name.presence || company.presence || email, email: email) if email
      ([ first ] + people.to_a).compact.select(&:email).uniq(&:email)
    end

    # The steps of a stage's plan it hasn't had yet, each due its days on from today. A lead moved
    # back to a stage it's been at doesn't get them again.
    def lay_out_plan!(stage, by: Current.user)
      had = steps.where.not(playbook_step_id: nil).pluck(:playbook_step_id)
      planned = stage.playbook_steps.ordered.reject { had.include?(it.id) }
      return if planned.empty?

      planned.each do |step|
        steps.create!(title: step.title, due_on: Date.current + step.days_after, playbook_step: step, template_id: step.template_id, created_by: by)
      end
      log!("plan", by: by, data: { stage: stage.name, steps: planned.map(&:title) })
      sync_next_step!
    end

    # A step added by hand, or after a call. One just like an open one (same title and date) isn't added twice.
    def add_step!(title:, due_on: nil, by: Current.user, template_id: nil)
      title = title.to_s.squish.presence || "Follow up"
      return steps.open.find_by(title: title, due_on: due_on) if steps.open.exists?(title: title, due_on: due_on)

      step = steps.create!(title: title, due_on: due_on.presence, created_by: by, template_id: template_id.presence)
      log!("step_added", by: by, data: { step: step.title, on: step.due_on&.iso8601 })
      sync_next_step!
      step
    end

    # Done (counting as being in touch), or open again.
    def complete_step!(step, by: Current.user)
      return step if step.done?

      transaction do
        step.update!(done_at: Time.current, done_by: by&.person)
        activity = log!("step_done", by: by, data: { step: step.title })
        update_columns(last_activity_at: activity.created_at)
        sync_next_step!
      end
      step
    end

    def reopen_step!(step, by: Current.user)
      return step unless step.done?

      step.update!(done_at: nil, done_by: nil)
      sync_next_step!
      step
    end

    # Its next step and date, from its earliest open step (or none), without a history line: the
    # steps themselves are the history.
    def sync_next_step!
      first = steps.open.in_order.first
      update_columns(next_step: first&.title, next_step_on: first&.due_on, updated_at: Time.current)
    end

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
