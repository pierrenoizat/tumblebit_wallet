class AddTumblerPublicKeyToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :tumbler_public_key, :string
  end
end
