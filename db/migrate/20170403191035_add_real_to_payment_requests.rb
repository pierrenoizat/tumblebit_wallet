class AddRealToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :real, :integer, array: true, default: []
  end
end
