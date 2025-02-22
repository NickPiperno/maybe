class ScenarioAnalyzer
  attr_reader :scenario, :family

  def initialize(scenario)
    @scenario = scenario
    @family = scenario.family
  end

  def analyze
    # Get actual financial data
    snapshot = family.snapshot_transactions
    income_series = snapshot[:income_series]
    spending_series = snapshot[:spending_series]
    savings_rate_series = snapshot[:savings_rate_series]

    return nil unless income_series&.values&.any? && spending_series&.values&.any?

    # Calculate current averages
    current_monthly_income = calculate_average(income_series)
    current_monthly_expenses = calculate_average(spending_series)
    current_savings_rate = calculate_average_rate(savings_rate_series)

    # Calculate scenario targets
    target_monthly_income = current_monthly_income * (1 + (scenario.income_adjustment || 0) / 100.0)
    target_monthly_expenses = current_monthly_expenses * (1 + (scenario.expense_adjustment || 0) / 100.0)
    target_savings_rate = scenario.savings_rate || current_savings_rate

    # Generate AI recommendations
    generate_recommendations(
      current_monthly_income: current_monthly_income,
      current_monthly_expenses: current_monthly_expenses,
      current_savings_rate: current_savings_rate,
      target_monthly_income: target_monthly_income,
      target_monthly_expenses: target_monthly_expenses,
      target_savings_rate: target_savings_rate
    )
  end

  private

  def calculate_average(series)
    return 0 unless series&.values&.any?
    total = series.values.sum { |v| v.value.amount }
    total / series.values.size
  end

  def calculate_average_rate(series)
    return 0 unless series&.values&.any?
    total = series.values.sum { |v| v.value }
    (total / series.values.size) * 100
  end

  def generate_recommendations(current_monthly_income:, current_monthly_expenses:, current_savings_rate:,
                             target_monthly_income:, target_monthly_expenses:, target_savings_rate:)
    # Calculate the mathematical feasibility first
    current_savings = current_monthly_income - current_monthly_expenses
    target_savings_needed = target_monthly_income * (target_savings_rate / 100.0)
    savings_gap = target_savings_needed - current_savings
    
    # Calculate required changes to bridge the gap
    required_income_increase_pct = ((current_monthly_income + savings_gap) / current_monthly_income - 1) * 100
    required_expense_decrease_pct = ((current_monthly_expenses - savings_gap) / current_monthly_expenses - 1) * 100

    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    prompt = <<~PROMPT
      As a financial advisor, analyze this scenario with mathematical rigor:

      Current Financial State:
      - Monthly Income: #{current_monthly_income.round(2)}
      - Monthly Expenses: #{current_monthly_expenses.round(2)}
      - Current Savings: #{current_savings.round(2)}
      - Current Savings Rate: #{current_savings_rate.round(1)}%

      Scenario Targets:
      - Target Monthly Income: #{target_monthly_income.round(2)} (#{scenario.income_adjustment}% change)
      - Target Monthly Expenses: #{target_monthly_expenses.round(2)} (#{scenario.expense_adjustment}% change)
      - Target Savings Rate: #{target_savings_rate.round(1)}%
      - Required Monthly Savings for Target: #{target_savings_needed.round(2)}
      - Current Gap to Target: #{savings_gap.round(2)}
      - Timeline: #{scenario.timeline_months} months

      Mathematical Analysis:
      - To reach target through income alone: Need #{required_income_increase_pct.round(1)}% income increase
      - To reach target through expenses alone: Need #{required_expense_decrease_pct.round(1)}% expense decrease
      - Planned changes: #{scenario.income_adjustment}% income increase, #{scenario.expense_adjustment}% expense decrease

      IMPORTANT GUIDELINES:
      1. Base feasibility score primarily on mathematical possibility
      2. Score of 0-20: Mathematically impossible with given adjustments
      3. Score of 21-40: Requires significant additional adjustments
      4. Score of 41-60: Possible but very challenging
      5. Score of 61-80: Achievable with additional moderate changes
      6. Score of 81-100: Highly achievable with current plan
      7. If current savings rate is negative, moving to positive requires more dramatic changes
      8. Consider timeline - shorter timelines need more aggressive changes

      Provide an analysis in JSON format with:
      1. Mathematically-grounded feasibility assessment
      2. Specific steps to achieve the targets (if possible)
      3. Clear explanation if targets are mathematically unattainable
      4. Potential risks and mitigation strategies

      Format your response as JSON with:
      {
        "feasibility_score": 0-100,
        "summary": "Brief assessment of mathematical feasibility",
        "recommendations": [
          {
            "type": "income|expense|savings",
            "title": "Specific action-oriented recommendation",
            "description": "Detailed explanation with concrete steps",
            "impact": "Expected impact on financial goals"
          }
        ],
        "risks": [
          {
            "title": "Risk title",
            "description": "Risk description",
            "mitigation": "How to mitigate this risk"
          }
        ]
      }
    PROMPT

    begin
      response = client.chat(
        parameters: {
          model: "gpt-4",
          messages: [
            { 
              role: "system", 
              content: "You are a mathematically rigorous financial advisor. Always calculate the numerical feasibility first, before making any recommendations. If a scenario is mathematically impossible with the given adjustments, you must explicitly state this and give a low feasibility score (0-20)."
            },
            { role: "user", content: prompt }
          ],
          temperature: 0.3  # Lower temperature for more consistent, conservative responses
        }
      )

      JSON.parse(response.dig("choices", 0, "message", "content"), symbolize_names: true)
    rescue => e
      Rails.logger.error "Error generating scenario analysis: #{e.message}"
      nil
    end
  end
end 