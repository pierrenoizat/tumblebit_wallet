class AddFakeIndicesToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :fake_indices, :text, array:true, default: []
  end
end
