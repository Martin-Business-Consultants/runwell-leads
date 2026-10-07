# frozen_string_literal: true

# A lead's score: points for what it does (a submission, an email opened, a
# link clicked, a note — Settings › Leads) and adjustments by hand. Crossing
# the qualification threshold moves a new or nurturing lead to qualified,
# and says so (lead.qualified).
module Leads::Lead::Scored
  extend ActiveSupport::Concern

  # The stages a lead can be qualified from by its score.
  QUALIFIABLE_STAGES = %w[new nurturing].freeze

  # A manual change to the score, with the reason recorded on the timeline.
  def adjust_score(points, reason:, user: Current.user)
    points = Integer(points, exception: false)
    raise ArgumentError, "Give a number of points other than 0" if points.nil? || points.zero?

    sign = points.positive? ? "+" : ""
    activity = record_activity(:score_changed, summary: "Score adjusted by #{sign}#{points}#{": #{reason.to_s.strip}" if reason.present?}",
      body: reason.to_s.strip.presence, points: points, user: user, data: {reason: reason.to_s.strip})
    track_event(:score_adjusted, points: points, reason: reason.to_s.strip, score: score)
    activity
  end

  def add_points(points)
    update_columns(score: score + points.to_i, updated_at: Time.current)
    qualify_if_due
  end

  def qualified_by_score?
    score >= Leads::Settings.current.threshold
  end

  private

  def qualify_if_due
    return unless QUALIFIABLE_STAGES.include?(stage) && qualified_by_score?

    change_stage("qualified", user: nil, audit: false)
    record_activity(:qualified, summary: "Qualified at a score of #{score}", data: {score: score}, user: nil)
    announce("lead.qualified")
  end
end
