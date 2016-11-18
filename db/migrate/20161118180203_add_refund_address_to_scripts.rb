class AddRefundAddressToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :refund_address, :string
  end
end
