class CreateSimulations < ActiveRecord::Migration
  def change
    create_table :simulations do |t|

      t.timestamps
    end
  end
end
