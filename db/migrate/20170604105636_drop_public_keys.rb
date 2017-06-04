class DropPublicKeys < ActiveRecord::Migration
  def change
    drop_table :public_keys
  end
end
