class AddNotifiedLowCreditIndexToUsers < ActiveRecord::Migration[5.2]
  def change
    add_index :users, :notified_low_credit
  end
end
