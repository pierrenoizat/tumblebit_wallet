class AddRToScripts < ActiveRecord::Migration
  def change
    add_column :scripts, :r, :text
  end
end
