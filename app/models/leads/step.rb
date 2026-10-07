# frozen_string_literal: true

module Leads
  # One email of a sequence: sent `delay` after the enrollment (the first
  # step) or after the step before it. The subject and body may say
  # {{name}}, {{first_name}}, {{email}} and {{company}}; the body is Markdown.
  class Step < ApplicationRecord
    DELAY_UNITS = %w[hours days].freeze
    PLACEHOLDERS = %w[name first_name email company].freeze

    belongs_to :sequence, class_name: "Leads::Sequence", inverse_of: :steps

    validates :subject, presence: true, length: {maximum: 200}
    validates :delay_amount, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than: 1000}
    validates :delay_unit, inclusion: {in: DELAY_UNITS}

    def delay = delay_amount.to_i.public_send(delay_unit)

    def send_after(time) = time + delay

    def number = position.to_i + 1

    def delay_label
      amount = delay_amount.to_i
      amount.zero? ? "Right away" : "#{amount} #{delay_unit.singularize.pluralize(amount)}"
    end

    def email_for(lead) = Leads::Step::Email.new(self, lead)
  end
end
