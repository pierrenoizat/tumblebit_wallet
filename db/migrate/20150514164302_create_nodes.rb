class CreateNodes < ActiveRecord::Migration
  def change
    create_table :nodes do |t|
      t.integer :left
      t.integer :right
      t.string :hash
      t.integer :height
      t.integer :tree_id

      t.timestamps null: false
    end
  end
end
