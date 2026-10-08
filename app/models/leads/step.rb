module Leads
  # One email of a sequence: sent `delay` after the lead joined (the first) or after the email
  # before. The subject and body may say {{name}}, {{first_name}}, {{email}} and {{company}}; the
  # body is rich text.
  class Step < ApplicationRecord
    DELAY_UNITS = %w[hours days].freeze
    PLACEHOLDERS = %w[name first_name email company].freeze

    belongs_to :sequence, class_name: "Leads::Sequence", inverse_of: :steps

    validates :subject, presence: true, length: { maximum: 200 }
    validates :delay_amount, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than: 1000 }
    validates :delay_unit, inclusion: { in: DELAY_UNITS }

    before_create { self.position = (sequence.steps.maximum(:position) || -1) + 1 }

    def delay = delay_amount.to_i.public_send(delay_unit)

    def send_after(time) = time + delay

    def number = sequence.steps.index(self).to_i + 1

    # "Right away", "2 days after joining", "1 hour after the last".
    def delay_label
      amount = delay_amount.to_i
      return "Right away" if amount.zero?

      "#{amount} #{delay_unit.singularize.pluralize(amount)} after #{number == 1 ? "joining" : "the last"}"
    end

    def email_for(lead) = Leads::Step::Email.new(self, lead)

    # Up or down one place among its sequence's emails.
    def move(direction)
      siblings = sequence.steps.to_a
      index = siblings.index(self) or return false
      target = direction.to_s == "up" ? index - 1 : index + 1
      return false unless target.between?(0, siblings.size - 1)

      siblings.insert(target, siblings.delete_at(index))
      transaction { siblings.each_with_index { |step, position| step.update_column(:position, position) } }
      true
    end
  end
end
