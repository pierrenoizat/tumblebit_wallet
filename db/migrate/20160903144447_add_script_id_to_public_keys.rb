class AddScriptIdToPublicKeys < ActiveRecord::Migration
  def change
    add_column :public_keys, :script_id, :integer
  end
end
