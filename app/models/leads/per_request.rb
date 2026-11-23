module Leads
  # What a request reads once however many leads it shows: the first stage (where new leads land,
  # and the one a lead may sit in without a next step) and when a lead is going cold. Reset after every request and job.
  class PerRequest < ActiveSupport::CurrentAttributes
    attribute :first_stage_id, :cold_after_days, :cold_read

    def first_stage_id = super || (self.first_stage_id = Stage.first_stage&.id)

    # Days without anyone in touch before an open lead is going cold (Setting), nil when that's off.
    def cold_after_days
      return super if cold_read

      self.cold_read = true
      self.cold_after_days = Setting.current.cold_after_days
    end
  end
end
