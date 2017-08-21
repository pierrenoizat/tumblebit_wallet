class AddBlindingFactorToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :blinding_factor, :string
  end
end
