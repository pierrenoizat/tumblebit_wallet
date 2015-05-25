class AddNodePathToNodes < ActiveRecord::Migration
  def change
    add_column :nodes, :node_path, :string
  end
end
