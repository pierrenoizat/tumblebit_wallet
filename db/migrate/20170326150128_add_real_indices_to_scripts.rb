class AddRealIndicesToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :real_indices, :string, array: true, default: []
  end
end