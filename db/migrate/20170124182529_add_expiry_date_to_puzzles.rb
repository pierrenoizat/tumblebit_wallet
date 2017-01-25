class AddExpiryDateToPuzzles < ActiveRecord::Migration
  def change
    add_column :puzzles, :expiry_date, :datetime
  end
end
