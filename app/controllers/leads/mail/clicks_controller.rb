# frozen_string_literal: true

# A tracked link in a sequence email (public, signed): the click goes on the
# lead's timeline, then on to where the link pointed. The token carries the
# URL, so it can't be pointed anywhere else.
module Leads
  module Mail
    class ClicksController < ActionController::Base
      include PluginGated
      plugin :leads

      def show
        message, url = Message.find_by_click_token(params[:token])

        if message
          message.record_click(url)
          redirect_to url, allow_other_host: true, status: :see_other
        else
          head :not_found
        end
      end
    end
  end
end
