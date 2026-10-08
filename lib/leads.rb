require "leads/version"
require "leads/engine"

# Leads: the people who might become clients. They come in from a form on your website (the
# capture endpoint), by hand or from an agent; each gathers a timeline and a score, carries
# follow-up tasks, can be sent email sequences, and becomes a client in one step.
module Leads
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "leads_"

  # Signs what an email's links carry (Leads::Message, Leads::Lead#unsubscribe_token): URL-safe,
  # so a token sits in a path segment as it is.
  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("leads/mail", 32), url_safe: true, serializer: JSON
    )
  end
end
