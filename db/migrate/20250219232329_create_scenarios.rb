class CreateScenarios < ActiveRecord::Migration[7.2]
  def change
    create_table :scenarios, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :name
      t.text :description
      t.decimal :income_adjustment
      t.decimal :expense_adjustment
      t.decimal :savings_rate
      t.integer :timeline_months

      t.timestamps
    end
  end
end
