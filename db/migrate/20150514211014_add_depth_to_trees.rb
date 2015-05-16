class AddDepthToTrees < ActiveRecord::Migration
  def change
    add_column :trees, :depth, :integer
    add_column :trees, :count, :integer
    add_column :trees, :error_count, :integer
    add_column :trees, :height, :integer
  end
end
