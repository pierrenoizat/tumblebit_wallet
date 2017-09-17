class DropClients < ActiveRecord::Migration[5.1]
  def change
    drop_table :clients
  end
end
