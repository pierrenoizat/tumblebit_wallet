class CreatePuzzles < ActiveRecord::Migration
  def change
    create_table :puzzles do |t|
      t.integer :script_id
      t.text :y
      t.text :encrypted_signature

      t.timestamps null: false
    end
  end
end
