class RemoveRoValuesfromPayments < ActiveRecord::Migration
  def change
    remove_column :payments, :ro_values
  end
end
