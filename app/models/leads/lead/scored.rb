# A lead's score: points for what it does (coming in from the website, an email opened, a link
# clicked, a note; Settings › Leads) and adjustments by hand. Crossing the threshold moves a new or
# nurturing lead to qualified.
module Leads::Lead::Scored
  extend ActiveSupport::Concern

  # The stages a lead can be qualified from by its score.
  QUALIFIABLE_STAGES = %w[new nurturing].freeze

  # A change to the score by hand, with the reason on the timeline.
  def adjust_score(points, reason:, user: Current.user)
    points = Integer(points.to_s, exception: false)
    raise ArgumentError, "Give a number of points other than 0" if points.nil? || points.zero?

    reason = reason.to_s.strip
    record_activity(:score_changed, summary: "Score #{points.positive? ? "+" : ""}#{points}#{": #{reason}" if reason.present?}",
      body: reason.presence, points: points, user: user, data: { reason: reason })
  end

  def add_points(points)
    update_columns(score: score + points.to_i, updated_at: Time.current)
    qualify_if_due
  end

  def qualified_by_score? = score >= Leads::Settings.current.threshold

  private
    def qualify_if_due
      return unless QUALIFIABLE_STAGES.include?(stage) && qualified_by_score?

      change_stage("qualified", user: nil)
      record_activity(:qualified, summary: "Qualified at a score of #{score}", data: { score: score }, user: nil)
    end
end
