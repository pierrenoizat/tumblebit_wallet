class AddUrlToTrees < ActiveRecord::Migration
  def change
    add_column :trees, :url, :string
  end
end
