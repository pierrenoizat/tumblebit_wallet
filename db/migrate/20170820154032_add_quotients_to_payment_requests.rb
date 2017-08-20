class AddQuotientsToPaymentRequests < ActiveRecord::Migration
  def change
    remove_column :payment_requests, :y
    add_column :payment_requests, :quotients, :text, array:true, default: []
  end
end
