class CreateOrderDiscounts < ActiveRecord::Migration[7.2]
  def change
    create_table :order_discounts do |t|
      t.string :key
      t.references :order, null: false, foreign_key: true
      t.integer :value

      t.timestamps
    end
  end
end
