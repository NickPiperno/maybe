class CreateAiRecommendations < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_recommendations, id: :uuid do |t|
      t.references :family, null: false, foreign_key: true, type: :uuid
      t.string :recommendation_type, null: false
      t.string :status, null: false, default: 'pending'
      t.string :title, null: false
      t.text :description, null: false
      t.integer :amount_cents
      t.string :currency

      t.timestamps

      t.index [:family_id, :recommendation_type]
      t.index [:family_id, :status]
      t.check_constraint "status IN ('pending', 'accepted', 'rejected', 'dismissed')"
      t.check_constraint "recommendation_type IN ('spending_analysis', 'budget_adjustment', 'savings_opportunity')"
    end
  end
end
