module Leads
  # A file or a link kept on a lead: the proposal, a deck, the call's notes in a Google Doc. Files
  # go to the client's documents when the lead is won, and links into the note that tells the story.
  class Attachment < ApplicationRecord
    self.table_name = "leads_attachments"

    belongs_to :lead, class_name: "Leads::Lead"
    belongs_to :user, optional: true
    has_one_attached :file

    MAX_SIZE = ENV.fetch("RUNWELL_MAX_UPLOAD_MB", 100).to_i.megabytes

    normalizes :name, with: ->(name) { name.to_s.squish.presence }
    normalizes :url, with: ->(url) { url.to_s.strip.presence&.then { it.match?(%r{\A[a-z][a-z0-9+.-]*://}i) ? it : "https://#{it}" } }

    validate :file_or_link
    validates :url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must be a web address" }, allow_nil: true
    validate :file_within_limit

    scope :newest, -> { order(created_at: :desc, id: :desc) }

    def link? = url.present? && !file.attached?
    def display_name = name || (file.attached? ? file.filename.to_s : url.to_s.sub(%r{\Ahttps?://}i, "").truncate(60))
    def removable_by?(person) = user&.person == person.person || person.can?(:delete_records)

    private
      def file_or_link
        errors.add(:base, "Add a file or a link") unless file.attached? || url.present?
      end

      def file_within_limit
        errors.add(:file, "is over the #{ActiveSupport::NumberHelper.number_to_human_size(MAX_SIZE)} limit") if file.attached? && file.byte_size > MAX_SIZE
      end
  end
end
