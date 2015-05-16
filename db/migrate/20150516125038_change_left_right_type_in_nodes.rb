class ChangeLeftRightTypeInNodes < ActiveRecord::Migration
  def up
      change_column :nodes, :left, :string
      change_column :nodes, :right, :string
    end

    def down
      change_column :nodes, :left, :integrer
      change_column :nodes, :right, :integrer
    end
end
