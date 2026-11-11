module Leads
  # A step an open lead moves through on its way to a sale (New, Call booked, Call held, Proposal
  # sent), in the install's order and words (Settings › Plugins › Leads). Won and Lost aren't
  # stages: they close a lead (Lead#state). The first stage is where new leads land.
  class Stage < ApplicationRecord
    self.table_name = "leads_stages"

    has_many :leads, class_name: "Leads::Lead", dependent: :restrict_with_error

    normalizes :name, with: ->(name) { name.to_s.squish }
    validates :name, presence: true, length: { maximum: 40 }, uniqueness: { case_sensitive: false }

    scope :ordered, -> { order(:position, :id) }

    after_commit { Leads::PerRequest.first_stage_id = nil }

    before_create { self.position = (Stage.maximum(:position) || -1) + 1 if position.to_i.zero? && Stage.exists? }

    def self.first_stage = ordered.first
    def self.options = ordered.map { [ it.name, it.id ] }

    # Only a stage no lead sits in, open or closed, and never the last one.
    def deletable? = !leads.exists? && Stage.count > 1

    def refusal_to_delete
      if Stage.count <= 1 then "Leads need at least one stage."
      elsif leads.exists? then "#{leads.count} #{leads.count == 1 ? "lead is" : "leads are"} in #{name}: move them first."
      end
    end

    # Up or down one place, swapping with its neighbour.
    def move!(direction)
      stages = Stage.ordered.to_a
      index = stages.index(self)
      other = direction.to_s == "up" ? (stages[index - 1] if index.positive?) : stages[index + 1]
      return unless other

      stages[index], stages[stages.index(other)] = other, self
      transaction { stages.each_with_index { |stage, position| stage.update_columns(position: position) } }
      Leads::PerRequest.first_stage_id = nil
    end
  end
end
