class AddSolutionToPayments < ActiveRecord::Migration
  def change
    add_column :payments, :solution, :string
  end
end
