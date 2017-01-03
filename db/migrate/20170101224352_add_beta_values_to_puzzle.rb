class AddBetaValuesToPuzzle < ActiveRecord::Migration
    def change
      add_column :puzzles, :beta_values, :text, array:true, default: []
    end
  end
