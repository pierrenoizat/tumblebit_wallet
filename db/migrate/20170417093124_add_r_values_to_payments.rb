class AddRValuesToPayments < ActiveRecord::Migration
  def change
    remove_column :payments, :r
    add_column :payments, :r_values, :text, array:true, default: []
  end
end
