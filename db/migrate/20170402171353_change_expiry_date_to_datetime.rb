class ChangeExpiryDateToDatetime < ActiveRecord::Migration
  def change
    change_column :payment_requests, :expiry_date, :datetime
  end
end
