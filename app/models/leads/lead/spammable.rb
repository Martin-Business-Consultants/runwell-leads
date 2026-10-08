# Spam: a lead that isn't anyone, moved out of sight (stage "spam") rather than deleted, so the
# same address coming back from a form stays quiet (Capturable). It leaves its sequences like any
# finished lead, and "Not spam" puts it back as new.
module Leads::Lead::Spammable
  extend ActiveSupport::Concern

  def spam? = stage == "spam"

  def mark_spam(user: Current.user) = change_stage("spam", user: user)

  def unmark_spam(user: Current.user) = spam? && change_stage("new", user: user)
end
