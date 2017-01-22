class AddTumblerKeyToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :tumbler_key, :string
  end
end
