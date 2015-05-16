class AddRollColumnsToTrees < ActiveRecord::Migration
  def self.up
      add_column :trees, :roll_file_name,    :string
      add_column :trees, :roll_content_type, :string
      add_column :trees, :roll_file_size,    :integer
      add_column :trees, :roll_updated_at,   :datetime
    end

    def self.down
      remove_column :trees, :roll_file_name
      remove_column :trees, :roll_content_type
      remove_column :trees, :roll_file_size
      remove_column :trees, :roll_updated_at
    end
end
