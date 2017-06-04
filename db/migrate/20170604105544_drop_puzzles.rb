class DropPuzzles < ActiveRecord::Migration
  def change
    drop_table :puzzles
  end
end
