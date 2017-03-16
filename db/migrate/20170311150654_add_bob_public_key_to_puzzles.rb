class AddBobPublicKeyToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :bob_public_key, :string
  end
end
