class AddLeftIdToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :left_id, :integer
    add_column :nodes, :right_id, :integer
  end
end
