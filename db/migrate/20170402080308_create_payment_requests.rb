class CreatePaymentRequests < ActiveRecord::Migration
  def change
    create_table :payment_requests do |t|
      t.string :title
      t.string :tumbler_public_key
      t.string :bob_public_key
      t.date :expiry_date
      t.string :r
      t.text :real_indices
      t.text :beta_values
      t.text :c_values
      t.text :epsilon_values

      t.timestamps null: false
    end
  end
end
