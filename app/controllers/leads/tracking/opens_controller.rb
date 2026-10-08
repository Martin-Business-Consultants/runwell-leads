module Leads
  module Tracking
    # The open pixel in a sequence's email (public, signed). Always the same transparent GIF.
    class OpensController < ::ApplicationController
      allow_unauthenticated_access

      PIXEL = Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7").freeze

      def show
        Message.find_by_open_token(params[:token])&.record_open if Runwell::Plugins.enabled?(:leads)
        response.set_header("Cache-Control", "no-store")
        send_data PIXEL, type: "image/gif", disposition: "inline"
      end
    end
  end
end
