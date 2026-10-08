# Someone who rang has a phone number and maybe a name, but no email address yet.
class AllowLeadsWithoutEmail < ActiveRecord::Migration[8.1]
  def change
    change_column_null :leads_leads, :email, true
  end
end
