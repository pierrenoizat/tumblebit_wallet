class DropLeafNodes < ActiveRecord::Migration
  def change
    drop_table :leaf_nodes
  end
end
