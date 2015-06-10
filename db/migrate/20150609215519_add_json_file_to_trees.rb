class AddJsonFileToTrees < ActiveRecord::Migration
  def self.up
      add_attachment :trees, :json_file
    end

    def self.down
      remove_attachment :trees, :json_file
    end
end
