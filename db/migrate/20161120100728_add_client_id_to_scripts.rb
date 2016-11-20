class AddClientIdToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :client_id, :integer
  end
end
