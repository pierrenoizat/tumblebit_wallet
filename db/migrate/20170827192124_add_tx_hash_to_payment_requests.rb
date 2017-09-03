class AddTxHashToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :tx_hash, :string
    add_column :payment_requests, :index, :integer
    add_column :payment_requests, :amount, :integer
    add_column :payment_requests, :confirmations, :integer
  end
end
