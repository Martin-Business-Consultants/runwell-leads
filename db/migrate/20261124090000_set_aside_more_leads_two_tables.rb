# An install that had Leads 2 still has two of its tables under names 3.1 uses: leads_templates and
# leads_steps (its sequences' templates and steps, left in place by 3.0). They're renamed aside in
# place (leads_v2_*, as 3.0 did with the rest; SQLite renames in place and repoints the foreign keys,
# so nothing cascades) before 3.1 makes its own. Told apart by a column only 3.1's have, so 3.1's
# tables are never touched. Runs before CreateLeadsJourneyTables; an install that never had 2 has
# nothing to move. (3.1.0 shipped without this and failed to boot on such an install.)
class SetAsideMoreLeadsTwoTables < ActiveRecord::Migration[8.1]
  def up
    set_aside :leads_templates, unless_column: :name
    set_aside :leads_steps, unless_column: :lead_id
  end

  def down; end

  private
    def set_aside(table, unless_column:)
      return unless table_exists?(table) && !column_exists?(table, unless_column)

      aside = table.to_s.sub("leads_", "leads_v2_")
      return if table_exists?(aside)

      rename_table table, aside
    end
end
