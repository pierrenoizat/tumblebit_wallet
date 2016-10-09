class DropNodes < ActiveRecord::Migration
  def change
    drop_table :nodes
  end
end
