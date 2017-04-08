class AddYToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :y, :string
  end
end
