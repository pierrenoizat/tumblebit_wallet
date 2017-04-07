class AddStateToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :aasm_state, :string
  end
end
