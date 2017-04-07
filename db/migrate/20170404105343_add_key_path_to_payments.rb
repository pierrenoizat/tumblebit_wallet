class AddKeyPathToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :key_path, :string
    remove_column :payments, :alice_public_key
  end
end
