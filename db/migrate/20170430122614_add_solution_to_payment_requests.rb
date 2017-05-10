class AddSolutionToPaymentRequests < ActiveRecord::Migration
  def change
    add_column :payment_requests, :solution, :string
  end
end
