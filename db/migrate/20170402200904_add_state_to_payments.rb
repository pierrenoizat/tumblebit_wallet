class AddStateToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :aasm_state, :string
  end
end
