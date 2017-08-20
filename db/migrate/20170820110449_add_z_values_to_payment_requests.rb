class AddZValuesToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :z_values, :text, array:true, default: []
  end
end
