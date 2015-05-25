class AddLeafPathToLeafNodes < ActiveRecord::Migration
  def change
    add_column :leaf_nodes, :leaf_path, :string
  end
end
