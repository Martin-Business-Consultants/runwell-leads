module Leads
  # What a request reads once however many leads it shows: the first stage (where new leads land,
  # and the one a lead may sit in without a next step). Reset after every request and job.
  class PerRequest < ActiveSupport::CurrentAttributes
    attribute :first_stage_id

    def first_stage_id = super || (self.first_stage_id = Stage.first_stage&.id)
  end
end
