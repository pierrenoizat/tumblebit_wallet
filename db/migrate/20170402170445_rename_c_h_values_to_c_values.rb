class RenameCHValuesToCValues < ActiveRecord::Migration
  def change
    rename_column :payments, :c_h_values, :c_values
    add_column :payments, :h_values, :text, array:true, default: []
  end
end
