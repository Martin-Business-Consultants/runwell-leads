module Leads
  # Someone else at a lead's business: who decides, who's keen on it, who else is involved. The
  # lead's own name and email stay its first person. Each becomes a contact of the client when the
  # lead is won (Leads::Win), and can be emailed from the lead.
  class Person < ApplicationRecord
    self.table_name = "leads_people"

    ROLES = { "decides" => "Decides", "champion" => "Champion", "involved" => "Involved" }.freeze

    belongs_to :lead, class_name: "Leads::Lead"

    normalizes :email, with: ->(email) { email.to_s.strip.downcase.presence }
    normalizes :name, :phone, :title, with: ->(value) { value.to_s.squish.presence }

    validates :name, presence: true, length: { maximum: 120 }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
    validates :role, inclusion: { in: ROLES.keys }, allow_nil: true

    def role=(value)
      super(value.presence)
    end

    def role_label = ROLES[role]
    def first_name = name.split.first
  end
end
