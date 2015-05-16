class FixNodeColumnName < ActiveRecord::Migration
  def self.up
      rename_column :nodes, :hash, :node_hash
    end

    def self.down
      # rename back if you need or do something else or do nothing
    end
end
