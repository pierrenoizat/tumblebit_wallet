class AddEscrowTxidToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :escrow_txid, :text
  end
end
