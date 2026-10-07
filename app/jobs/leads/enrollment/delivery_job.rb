# frozen_string_literal: true

# Sends every enrollment's due step (Leads::Enrollment::Deliverable).
class Leads::Enrollment::DeliveryJob < ApplicationJob
  queue_as :default

  def perform
    Leads::Enrollment.deliver_due_now
  end
end
