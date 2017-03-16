class AddAlicePublicKeyToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :alice_public_key, :string
  end
end
