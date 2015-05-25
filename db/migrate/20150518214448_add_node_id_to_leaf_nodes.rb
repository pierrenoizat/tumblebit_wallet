class AddNodeIdToLeafNodes < ActiveRecord::Migration
  def change
    add_column :leaf_nodes, :node_id, :integer
  end
end
