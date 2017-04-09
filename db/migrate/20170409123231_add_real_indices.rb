class AddRealIndices < ActiveRecord::Migration
  def change
    add_column :payments, :real_indices, :integer, array:true, default: []
  end
end
