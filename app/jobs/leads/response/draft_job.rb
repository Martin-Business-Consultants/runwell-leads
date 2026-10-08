# Drafts a lead's replies with the AI plugin (Leads::Response::Drafting), away from the request.
class Leads::Response::DraftJob < ApplicationJob
  queue_as :default

  def perform(response)
    response.generate!
  end
end
