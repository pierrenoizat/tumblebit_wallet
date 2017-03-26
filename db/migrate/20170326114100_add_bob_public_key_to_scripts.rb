class AddBobPublicKeyToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :bob_public_key, :string
  end
end
