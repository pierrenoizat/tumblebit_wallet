class CreatePublicKeys < ActiveRecord::Migration
  def change
    create_table :public_keys do |t|
      t.string :name
      t.string :compressed

      t.timestamps null: false
    end
  end
end
