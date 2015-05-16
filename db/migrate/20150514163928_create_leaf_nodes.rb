class CreateLeafNodes < ActiveRecord::Migration
  def change
    create_table :leaf_nodes do |t|
      t.string :name
      t.decimal :credit, precision: 30, scale: 2
      t.string :nonce
      t.integer :height
      t.integer :tree_id

      t.timestamps null: false
    end
  end
end
