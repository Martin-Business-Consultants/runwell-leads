# frozen_string_literal: true

require "leads/engine"

# Leads: lead nurturing on top of the Forms plugin. Every form submission
# with an email address becomes (or updates) a lead; leads gather an
# activity timeline and a score, carry follow-up tasks, and can be enrolled
# in email sequences that the plugin sends, tracks and lets people leave.
# Installed from its own repository (docs/plugins.md in the core).
module Leads
  # Plugin tables are prefixed with the plugin's key.
  def self.table_name_prefix = "leads_"

  # Scoring, sender and per-form capture (Settings › Leads, Leads::Settings).
  SETTING_KEY = "leads_settings"

  # Signs what an email's links carry (Leads::Message, Leads::Lead#unsubscribe_token):
  # URL-safe, so a token sits in a path segment as it is.
  def self.verifier
    @verifier ||= ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("leads/mail", 32), url_safe: true, serializer: JSON
    )
  end
end
