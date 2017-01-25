class AddRToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :r, :text
  end
end
