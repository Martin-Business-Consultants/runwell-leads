# frozen_string_literal: true

# The open pixel in a sequence email (public, signed): the first load marks
# the email opened. Always a 1×1 transparent GIF, whatever the token, so a
# mail client never shows a broken image. Not an ApplicationController:
# image proxies (Gmail's) announce old browsers, which allow_browser refuses.
module Leads
  module Mail
    class OpensController < ActionController::Base
      include PluginGated
      plugin :leads

      PIXEL = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

      def show
        Message.find_by_open_token(params[:token])&.record_open
        response.headers["Cache-Control"] = "no-store, private"
        send_data PIXEL, type: "image/gif", disposition: "inline"
      end
    end
  end
end
