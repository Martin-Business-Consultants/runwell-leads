module Leads
  # An email to start from (Settings › Plugins › Leads): a subject and a body with {{fields}} filled
  # from the lead and whoever's writing, so the recap or the follow-up isn't written from nothing.
  # It's a starting point: the email is edited before it goes.
  class Template < ApplicationRecord
    self.table_name = "leads_templates"

    FIELDS = {
      "first_name" => "their first name", "name" => "their name", "company" => "their business",
      "my_first_name" => "your first name", "my_name" => "your name", "business" => "your business's name"
    }.freeze

    has_many :playbook_steps, class_name: "Leads::PlaybookStep", dependent: :nullify
    has_many :steps, class_name: "Leads::Step", dependent: :nullify

    normalizes :name, :subject, with: ->(value) { value.to_s.squish }
    validates :name, presence: true, length: { maximum: 80 }, uniqueness: { case_sensitive: false }
    validates :subject, presence: true, length: { maximum: 200 }

    scope :ordered, -> { order(:position, :id) }

    before_create { self.position = (Template.maximum(:position) || -1) + 1 }

    def self.options = ordered.map { [ it.name, it.id ] }

    # The subject and body for this lead (or one of its people), from this sender.
    def fill(lead, to: nil, sender: nil)
      values = Template.values_for(lead, to: to, sender: sender)
      [ Template.merge(subject, values), Template.merge(body.to_s, values, html: true) ]
    end

    def self.values_for(lead, to: nil, sender: nil)
      name = to&.name || lead.name
      {
        "first_name" => name.to_s.split.first.presence || "there", "name" => name.presence || "there",
        "company" => lead.company.to_s, "my_first_name" => sender&.display_name.to_s.split.first.to_s,
        "my_name" => sender&.display_name.to_s, "business" => ::Setting.current.brand_name
      }
    end

    def self.merge(text, values, html: false)
      text.gsub(/\{\{\s*(\w+)\s*\}\}/) do
        key = Regexp.last_match(1)
        next Regexp.last_match(0) unless values.key?(key)

        html ? ERB::Util.html_escape(values[key]) : values[key]
      end
    end
  end
end
