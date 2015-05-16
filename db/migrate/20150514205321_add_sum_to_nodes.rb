class AddSumToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :sum, :decimal, precision: 30, scale: 2
  end
end
