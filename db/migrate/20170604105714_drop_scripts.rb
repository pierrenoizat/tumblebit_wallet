class DropScripts < ActiveRecord::Migration
  def change
    drop_table :scripts
  end
end
