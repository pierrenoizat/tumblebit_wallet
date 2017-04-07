class CreateArraysToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :real_indices, :integer, array: true, default: []
    add_column :payment_requests, :beta_values, :text, array: true, default: []
    add_column :payment_requests, :c_values, :text, array: true, default: []
    add_column :payment_requests, :epsilon_values, :text, array: true, default: []
  end
end
