class Scenario < ApplicationRecord
  belongs_to :family

  validates :name, presence: true
  validates :timeline_months, presence: true, 
    numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 60 }
  validates :income_adjustment, :expense_adjustment,
    numericality: { allow_nil: true }
  validates :savings_rate,
    numericality: { allow_nil: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def simulate
    ScenarioSimulator.new(self).simulate
  end
end 