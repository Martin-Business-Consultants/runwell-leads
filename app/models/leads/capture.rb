module Leads
  # One form sent from a website (CapturesController), as a lead. Reads the fields every form has
  # (STANDARD, with the usual other spellings), keeps the rest as the lead's details (campaign,
  # click ids, landing page, the form's own questions), and decides what it is:
  #
  # - :duplicate: the same submission again (its external_id was seen), so nothing changes
  # - :again: someone with an open lead under the same address sent another form; it's added to
  #   their history and lead, not made a second time
  # - :returned: their lead was lost and they came back; it's reopened at the first stage
  # - :created: a new lead (also when their last one was won: more business from a client)
  #
  # A referral (referral_company or referral_contact given) is the business referred: the lead is
  # them, and whoever sent the form is kept as the referrer.
  class Capture
    STANDARD = {
      "name" => %w[name full_name], "email" => %w[email email_address], "phone" => %w[phone phone_number tel],
      "company" => %w[company business organization organisation], "website" => %w[website website_url url],
      "message" => %w[message comments notes body], "source" => %w[source form], "external_id" => %w[external_id submission_id]
    }.freeze
    REFERRAL = %w[referral_company referral_contact referral_website referral_email referral_phone referral_services].freeze
    MAX_DETAILS = 60
    MAX_VALUE = 2000

    attr_reader :lead, :outcome

    def initialize(params, key: nil)
      @fields = params.to_h.transform_keys(&:to_s)
                      .select { |name, value| name.match?(/\A[\w.-]{1,60}\z/) && (value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false) }
                      .transform_values { it.to_s.strip.first(MAX_VALUE) }.compact_blank
      @key = key
    end

    def call
      attributes = referral? ? referral_attributes : standard_attributes
      attributes[:details] = details
      attributes[:source] ||= @key&.name

      if attributes[:external_id] && (seen = Lead.find_by(external_id: attributes[:external_id]))
        return finish(seen, :duplicate)
      end

      earlier = Lead.where(email: attributes[:email]).newest.first if attributes[:email]
      if earlier && !earlier.won?
        came_back(earlier, attributes)
      else
        lead = Lead.new(attributes.merge(last_submitted_at: Time.current))
        return finish(lead, :created) if lead.save

        @errors = lead.errors.full_messages
        self
      end
    end

    def errors = @errors || []
    def saved? = errors.empty?

    private
      def finish(lead, outcome)
        @lead, @outcome = lead, outcome
        @key&.used! unless outcome == :duplicate
        self
      end

      def came_back(lead, attributes)
        outcome = lead.lost? ? :returned : :again
        Lead.transaction do
          lead.reopen!(by: nil, stage: Stage.first_stage) if lead.lost?
          fill = attributes.slice(:name, :phone, :company, :website).select { |name, _| lead[name].blank? }
          lead.update_columns(fill.merge(submissions_count: lead.submissions_count + 1, last_submitted_at: Time.current,
            details: lead.details.merge(attributes[:details]), updated_at: Time.current))
          lead.log!("submitted", by: nil, body: attributes[:message], data: { source: attributes[:source], external_id: attributes[:external_id] }.compact)
        end
        Leads::Mailer.notify_new(lead, returned: true) if outcome == :returned
        finish(lead, outcome)
      end

      def standard_attributes
        STANDARD.to_h { |attribute, names| [ attribute.to_sym, names.lazy.filter_map { @fields[it] }.first ] }.compact
      end

      def referral? = @fields["referral_company"].present? || @fields["referral_contact"].present?

      def referral_attributes
        sender = standard_attributes
        {
          name: @fields["referral_contact"], email: @fields["referral_email"], phone: @fields["referral_phone"],
          company: @fields["referral_company"], website: @fields["referral_website"],
          message: [ @fields["referral_services"], sender[:message] ].compact.join("\n\n").presence,
          source: sender[:source], external_id: sender[:external_id],
          referrer_name: sender[:name] || sender[:company], referrer_email: sender[:email]
        }.compact
      end

      # Everything else the form sent, kept as it came: campaign, click ids, landing page, answers.
      def details
        used = STANDARD.values.flatten + (referral? ? REFERRAL : []) + %w[cf-turnstile-response]
        @fields.except(*used).first(MAX_DETAILS).to_h
      end
  end
end
