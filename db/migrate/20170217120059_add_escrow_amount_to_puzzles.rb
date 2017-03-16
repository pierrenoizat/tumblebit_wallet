class AddEscrowAmountToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :escrow_amount, :integer
  end
end
