# frozen_string_literal: true

# What a lead takes from a form submission: the email address (the form's
# first email field with a value, or a field named "email"), and a name,
# phone and company from the fields people usually call them. The rest of
# the submission is kept as the lead's latest fields.
class Leads::Lead::SubmittedFields
  NAME_FIELDS = %w[name full_name your_name contact_name].freeze
  PHONE_FIELDS = %w[phone telephone phone_number mobile].freeze
  COMPANY_FIELDS = %w[company company_name organization organisation business].freeze

  def initialize(submission)
    @data = submission.data.is_a?(Hash) ? submission.data.stringify_keys : {}
    @fields = Array(submission.form&.fields).select { it.is_a?(Hash) }
  end

  attr_reader :data

  def email
    names = @fields.select { it["type"] == "email" }.map { it["name"].to_s } + ["email"]
    address = names.lazy.map { text(it) }.find(&:present?)
    address&.downcase if address&.match?(URI::MailTo::EMAIL_REGEXP)
  end

  def name
    first(NAME_FIELDS) || [text("first_name"), text("last_name")].compact_blank.join(" ").presence
  end

  def phone
    first(@fields.select { it["type"] == "tel" }.map { it["name"].to_s } + PHONE_FIELDS)
  end

  def company = first(COMPANY_FIELDS)

  # The lead's details the submission gives a value for (it never blanks one).
  def details
    {name: name, phone: phone, company: company}.compact_blank
  end

  private

  def first(names) = names.lazy.map { text(it) }.find(&:present?)

  def text(name)
    value = @data[name]
    value.is_a?(String) ? value.strip.presence : nil
  end
end
