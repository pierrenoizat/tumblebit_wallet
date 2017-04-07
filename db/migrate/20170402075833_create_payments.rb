class CreatePayments < ActiveRecord::Migration
  def change
    create_table :payments do |t|
      t.string :title
      t.string :tumbler_public_key
      t.string :alice_public_key
      t.datetime :expiry_date
      t.string :y
      t.string :r

      t.timestamps null: false
    end
    
    add_column :payments, :real_indices, :text, array:true, default: []
    add_column :payments, :beta_values, :text, array:true, default: []
    add_column :payments, :ro_values, :text, array:true, default: []
    add_column :payments, :k_values, :text, array:true, default: []
    add_column :payments, :c_h_values, :text, array:true, default: []
    
  end
end
