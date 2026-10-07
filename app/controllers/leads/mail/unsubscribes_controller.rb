# frozen_string_literal: true

# Leaving a lead's emails (public, signed by the lead's token). The page asks
# with one button; a mail client's one-click unsubscribe (List-Unsubscribe-Post,
# RFC 8058) posts straight here without a CSRF token. A link scanner
# fetching the page changes nothing.
module Leads
  module Mail
    class UnsubscribesController < ::ApplicationController
      include PluginGated
      plugin :leads

      skip_authorization
      skip_before_action :authenticate
      skip_forgery_protection only: :create

      layout "public"

      before_action :set_lead

      def show
      end

      def create
        @lead.unsubscribe
        if request.format.html? && params["List-Unsubscribe"].blank?
          render :show
        else
          head :ok
        end
      end

      private

      def set_lead
        @lead = Lead.find_by_unsubscribe_token(params[:token])
        render :invalid, status: :not_found unless @lead
      end
    end
  end
end
