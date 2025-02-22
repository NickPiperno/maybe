class CreateAnalysisStatuses < ActiveRecord::Migration[7.1]
  def change
    create_table :analysis_statuses do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.integer :status, null: false, default: 0
      t.integer :goal_type, null: false
      t.json :results
      t.string :current_step
      t.timestamps
    end

    add_index :analysis_statuses, [:family_id, :goal_type]
  end
end 