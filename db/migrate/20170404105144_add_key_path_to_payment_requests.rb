class AddKeyPathToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :key_path, :string
    remove_column :payment_requests, :bob_public_key
  end
end
