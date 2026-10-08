module Leads
  # A website's form posting a lead (public): the install's capture key in the path, the fields in
  # the body, form-encoded or JSON. A browser's form is sent on (redirect_to, else Settings ›
  # Leads' thanks page, else ours); a script gets JSON, from any origin.
  class CapturesController < ::ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection
    rate_limit to: 30, within: 1.minute, only: :create, with: -> { head :too_many_requests }

    layout "public"

    before_action :allow_any_origin
    before_action :set_settings, only: :create

    def create
      # A bot filled in the field people never see: thank it and keep nothing.
      lead = Lead.capture(request.request_parameters) unless params[:website_url].present?
      if lead || params[:website_url].present?
        respond_to do |format|
          format.json { render json: { ok: true }, status: :created }
          format.any { redirect_after || render(:thanks) }
        end
      else
        respond_to do |format|
          format.json { render json: { ok: false, error: "An email address is needed." }, status: :unprocessable_entity }
          format.any { render :missing_email, status: :unprocessable_entity }
        end
      end
    end

    def preflight
      response.set_header("Access-Control-Allow-Methods", "POST, OPTIONS")
      response.set_header("Access-Control-Allow-Headers", "Content-Type, Accept")
      response.set_header("Access-Control-Max-Age", "86400")
      head :no_content
    end

    private
      def allow_any_origin = response.set_header("Access-Control-Allow-Origin", "*")

      def set_settings
        @settings = Leads::Settings.current
        head :not_found unless Runwell::Plugins.enabled?(:leads) && @settings.matches_key?(params[:key])
      end

      def redirect_after
        url = [ params[:redirect_to], @settings.thanks_url ].find { it.to_s.match?(%r{\Ahttps?://}i) }
        redirect_to url, allow_other_host: true, status: :see_other if url
      end
  end
end
