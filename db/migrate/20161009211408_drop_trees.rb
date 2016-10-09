class DropTrees < ActiveRecord::Migration
  def change
    drop_table :trees
  end
end
