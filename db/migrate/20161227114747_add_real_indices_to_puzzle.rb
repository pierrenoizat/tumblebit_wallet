class AddRealIndicesToPuzzle < ActiveRecord::Migration
  def change
    add_column :puzzles, :real_indices, :text, array:true, default: []
  end
end
