# What a lead takes from a website form's post: the email address, and a name, phone and company
# from the field names people usually give them. Every other field is kept on the lead as it was
# sent, and `source` names the form ("Contact page"), for sequences that start from one form.
class Leads::Lead::Submission
  EMAIL_FIELDS = %w[email email_address your_email].freeze
  NAME_FIELDS = %w[name full_name your_name contact_name].freeze
  PHONE_FIELDS = %w[phone telephone phone_number mobile tel].freeze
  COMPANY_FIELDS = %w[company company_name organization organisation business].freeze
  # Not the lead's: the honeypot, where to go after, and what Rails adds.
  RESERVED = %w[key source redirect_to website_url authenticity_token utf8 commit controller action format].freeze
  MAX_FIELDS = 40

  def initialize(params)
    hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
    @data = hash.stringify_keys.transform_keys { it.to_s.strip.downcase.tr(" -", "__") }
  end

  def email
    address = first(EMAIL_FIELDS)&.downcase
    address if address&.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def name = first(NAME_FIELDS) || [ text("first_name"), text("last_name") ].compact_blank.join(" ").presence
  def phone = first(PHONE_FIELDS)
  def company = first(COMPANY_FIELDS)
  def source = text("source")&.truncate(100)

  # The lead's details the submission gives a value for (it never blanks one).
  def details = { name: name, phone: phone, company: company }.compact_blank

  # The rest, as text, so a lead's page can show what the form said.
  def fields
    known = EMAIL_FIELDS + NAME_FIELDS + PHONE_FIELDS + COMPANY_FIELDS + %w[first_name last_name] + RESERVED
    @data.except(*known).filter_map { |key, value| [ key.truncate(60), value.to_s.strip.truncate(2_000) ] if value.is_a?(String) && value.strip.present? }
         .first(MAX_FIELDS).to_h
  end

  private
    def first(names) = names.lazy.map { text(it) }.find(&:present?)

    def text(name)
      value = @data[name]
      value.is_a?(String) ? value.strip.presence&.truncate(200) : nil
    end
end
