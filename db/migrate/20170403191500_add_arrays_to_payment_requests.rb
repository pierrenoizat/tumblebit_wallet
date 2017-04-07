class AddArraysToPaymentRequests < ActiveRecord::Migration
  def change
    remove_column :payment_requests, :real_indices
    remove_column :payment_requests, :real
    remove_column :payment_requests, :beta_values
    remove_column :payment_requests, :c_values
    remove_column :payment_requests, :epsilon_values
  end
end
