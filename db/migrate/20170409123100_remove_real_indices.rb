class RemoveRealIndices < ActiveRecord::Migration
  def change
    remove_column :payments, :real_indices
  end
end
