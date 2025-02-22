class ScenarioSimulator
  attr_reader :scenario

  def initialize(scenario)
    @scenario = scenario
  end

  def simulate
    {
      monthly_projections: calculate_monthly_projections,
      summary: calculate_summary,
      analysis: ScenarioAnalyzer.new(scenario).analyze
    }
  end

  private

  def calculate_monthly_projections
    projections = []
    base_income = calculate_base_monthly_income
    base_expenses = calculate_base_monthly_expenses
    
    # Calculate monthly growth rates (distributed over the timeline)
    monthly_income_growth = scenario.income_adjustment ? (scenario.income_adjustment / scenario.timeline_months.to_f) : 0
    monthly_expense_reduction = scenario.expense_adjustment ? (scenario.expense_adjustment / scenario.timeline_months.to_f) : 0

    current_income = base_income
    current_expenses = base_expenses

    scenario.timeline_months.times do |month|
      # Progressive adjustments
      if scenario.income_adjustment
        current_income = base_income * (1 + ((month + 1) * monthly_income_growth) / 100.0)
      end

      if scenario.expense_adjustment
        current_expenses = base_expenses * (1 + ((month + 1) * monthly_expense_reduction) / 100.0)
      end

      # Calculate savings based on target rate or difference
      savings = calculate_savings(current_income, current_expenses)
      savings_rate = calculate_savings_rate(current_income, savings)

      # Add seasonal variations (example: higher expenses in winter months)
      seasonal_factor = calculate_seasonal_factor(month)
      adjusted_expenses = current_expenses * seasonal_factor

      projections << {
        month: month + 1,
        income: current_income,
        expenses: adjusted_expenses,
        savings: current_income - adjusted_expenses,
        savings_rate: ((current_income - adjusted_expenses) / current_income * 100.0),
        trends: {
          income_growth: ((current_income - base_income) / base_income * 100.0).round(1),
          expense_reduction: ((base_expenses - adjusted_expenses) / base_expenses * 100.0).round(1)
        }
      }
    end

    projections
  end

  def calculate_summary
    projections = calculate_monthly_projections
    total_savings = projections.sum { |p| p[:savings] }
    average_savings_rate = projections.sum { |p| p[:savings_rate] } / projections.size

    initial_projection = projections.first
    final_projection = projections.last

    {
      total_savings: total_savings,
      average_savings_rate: average_savings_rate,
      final_monthly_savings: final_projection[:savings],
      final_savings_rate: final_projection[:savings_rate],
      total_income_growth: final_projection[:trends][:income_growth],
      total_expense_reduction: final_projection[:trends][:expense_reduction],
      monthly_average_savings: (total_savings / projections.size)
    }
  end

  def calculate_base_monthly_income
    snapshot = scenario.family.snapshot_transactions
    return 7000.0 unless snapshot[:income_series]&.values&.any?

    total = snapshot[:income_series].values.sum { |v| v.value.amount }
    total / snapshot[:income_series].values.size
  end

  def calculate_base_monthly_expenses
    snapshot = scenario.family.snapshot_transactions
    return 5000.0 unless snapshot[:spending_series]&.values&.any?

    total = snapshot[:spending_series].values.sum { |v| v.value.amount }
    total / snapshot[:spending_series].values.size
  end

  def calculate_seasonal_factor(month)
    # Add slight seasonal variations to make projections more realistic
    # Higher expenses in winter months (assuming January is month 0)
    case (month % 12)
    when 0, 1, 11 # Winter months
      1.05  # 5% higher expenses
    when 6, 7, 8  # Summer months
      0.95  # 5% lower expenses
    else
      1.0   # Normal expenses
    end
  end

  def calculate_savings(income, expenses)
    if scenario.savings_rate
      income * (scenario.savings_rate / 100.0)
    else
      income - expenses
    end
  end

  def calculate_savings_rate(income, savings)
    return 0.0 if income.zero?
    (savings / income) * 100.0
  end
end 