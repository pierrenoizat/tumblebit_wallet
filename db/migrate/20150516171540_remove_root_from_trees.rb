class RemoveRootFromTrees < ActiveRecord::Migration
  def change
    remove_column :trees, :root, :string
  end
end
