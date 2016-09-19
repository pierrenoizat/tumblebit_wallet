class AddContractToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :contract, :text
  end
end
