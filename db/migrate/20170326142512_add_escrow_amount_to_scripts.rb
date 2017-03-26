class AddEscrowAmountToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :escrow_amount, :integer
    add_column :scripts, :escrow_txid, :string
  end
end
