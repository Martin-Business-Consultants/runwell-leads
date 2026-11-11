# Leads 3.0 replaces Leads 2 (scoring, email sequences, follow-ups; written for Runwell 2) under the
# same key. An install that had 2 keeps its tables, renamed aside in place (leads_v2_*; SQLite
# renames in place and repoints the foreign keys, so nothing cascades), for the next migration to
# bring its leads across. Its sequences, messages, templates and responses stay where they are,
# unread. An install that never had 2 has nothing to move.
class SetAsideLeadsTwoTables < ActiveRecord::Migration[8.1]
  TABLES = %w[leads_leads leads_activities leads_settings].freeze

  def up
    return unless table_exists?(:leads_leads) && column_exists?(:leads_leads, :score)

    TABLES.each { |table| rename_table table, table.sub("leads_", "leads_v2_") if table_exists?(table) }
  end

  def down
    TABLES.each do |table|
      aside = table.sub("leads_", "leads_v2_")
      rename_table aside, table if table_exists?(aside) && !table_exists?(table)
    end
  end
end
