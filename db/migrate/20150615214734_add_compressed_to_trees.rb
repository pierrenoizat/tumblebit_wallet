class AddCompressedToTrees < ActiveRecord::Migration
  def change
    add_column :trees, :compressed, :string
  end
end
