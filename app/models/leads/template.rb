module Leads
  # Something to send or say, kept in the Learning Center: an email, a text message or a call
  # script for a situation ("First reply to a website enquiry"), with {{placeholders}} filled in
  # for each lead on its Responses tab. Starts with a set the team can change (Defaults).
  class Template < ApplicationRecord
    include Defaults

    KINDS = { "email" => "Email", "text" => "Text message", "call" => "Phone call" }.freeze
    PLACEHOLDERS = %w[first_name name company email phone my_name business].freeze

    validates :kind, inclusion: { in: KINDS.keys }
    validates :title, presence: true, length: { maximum: 120 }
    validates :situation, length: { maximum: 200 }
    validates :subject, length: { maximum: 200 }

    scope :ordered, -> { order(:position, :id) }
    scope :of_kind, ->(kind) { where(kind: kind) }

    before_create { self.position = (self.class.of_kind(kind).maximum(:position) || -1) + 1 }

    def kind_label = KINDS.fetch(kind, kind.humanize)

    # The subject and body as this lead gets them, from this person: [subject, html, text].
    def filled_for(lead, sender: Current.user)
      values = values_for(lead, sender)
      html = fill(body.to_s, values) { ERB::Util.html_escape(it) }
      [ subject.present? ? fill(subject, values) { it } : nil, html, Leads::Step::Email.plain_text(html) ]
    end

    private
      def values_for(lead, sender)
        person = sender&.person
        { "first_name" => lead.name.to_s.split.first.presence || "there", "name" => lead.name.presence || "there",
          "company" => lead.company.to_s, "email" => lead.email.to_s, "phone" => lead.phone.to_s,
          "my_name" => person&.name.to_s.split.first.presence || person&.display_name.to_s, "business" => Setting.current.brand_name }
      end

      def fill(source, values)
        source.gsub(/\{\{\s*(\w+)\s*\}\}/) { values.key?($1) ? yield(values[$1]) : $& }
      end
  end
end
