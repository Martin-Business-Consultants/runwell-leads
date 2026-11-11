module Leads
  # Where a website sends its forms: POST /leads/capture/:token, JSON or form fields, no sign-in.
  # The token is a form's key (CaptureKey), so it can only add leads; a key that's gone, or the
  # plugin switched off, answers 404. Too many from one address in a minute answers 429. A website
  # should check for bots before posting (Turnstile, a honeypot): this adds what it's sent.
  #
  # Answers JSON: 201 { ok, id, outcome } for a new lead, 200 when it joined an existing one (the
  # same person again, or the same submission resent), 422 { ok: false, errors } when it can't be
  # a lead (no name, email or company).
  class CapturesController < ::ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    rate_limit to: 30, within: 1.minute, by: -> { request.remote_ip }, with: -> { render json: { ok: false, errors: [ "Too many at once: try again in a minute." ] }, status: :too_many_requests }

    def create
      return head(:not_found) unless Runwell::Plugins.enabled?(:leads)

      key = CaptureKey.find_by(token: params[:token]) or return head(:not_found)
      capture = Capture.new(fields, key: key).call
      if capture.saved?
        render json: { ok: true, id: capture.lead.id, outcome: capture.outcome }, status: (capture.outcome == :created ? :created : :ok)
      else
        render json: { ok: false, errors: capture.errors }, status: :unprocessable_entity
      end
    end

    private
      # The form's fields, whether sent as JSON or as a form, without Rails' own.
      def fields
        params.to_unsafe_h.except("controller", "action", "token", "format", "capture", "authenticity_token")
      end
  end
end
