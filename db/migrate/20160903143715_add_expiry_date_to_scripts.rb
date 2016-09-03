class AddExpiryDateToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :expiry_date, :datetime
  end
end
