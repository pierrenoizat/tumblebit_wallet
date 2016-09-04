class AddCategoryToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :category, :integer
  end
end
