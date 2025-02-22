require 'openai'
require 'concurrent'

class AiAnalyzer
  attr_reader :family

  def initialize(family)
    @family = family
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def generate_recommendations
    # Get relevant financial data
    spending_data = analyze_spending
    budget_data = analyze_budget
    savings_data = analyze_savings

    # Return early if no data is available for analysis
    return [] if [spending_data, budget_data, savings_data].all?(&:nil?)

    # Create futures for parallel processing
    spending_future = Concurrent::Future.execute do
      if spending_data
        generate_spending_insights(spending_data)
      end
    end

    budget_future = Concurrent::Future.execute do
      if budget_data
        generate_budget_insights(budget_data)
      end
    end

    savings_future = Concurrent::Future.execute do
      if savings_data
        generate_savings_insights(savings_data)
      end
    end

    # Generate recommendations using GPT in parallel
    recommendations = []
    
    # Wait for all futures to complete and create recommendations
    if spending_insights = spending_future.value
      recommendations << AiRecommendation.create!(
        family: family,
        recommendation_type: 'spending_analysis',
        status: 'pending',
        title: spending_insights[:title],
        description: spending_insights[:description]
      )
    end

    if budget_insights = budget_future.value
      amount = BigDecimal(budget_insights[:amount].to_s)
      recommendations << AiRecommendation.create!(
        family: family,
        recommendation_type: 'budget_adjustment',
        status: 'pending',
        title: budget_insights[:title],
        description: budget_insights[:description],
        amount_cents: amount.round.to_i,
        currency: family.currency
      )
    end

    if savings_insights = savings_future.value
      amount = BigDecimal(savings_insights[:amount].to_s)
      recommendations << AiRecommendation.create!(
        family: family,
        recommendation_type: 'savings_opportunity',
        status: 'pending',
        title: savings_insights[:title],
        description: savings_insights[:description],
        amount_cents: amount.round.to_i,
        currency: family.currency
      )
    end

    recommendations
  end

  private

  def analyze_spending
    stats = family.category_stats
    latest_entry_date = family.entries.maximum(:date)
    return nil unless latest_entry_date

    current_month = latest_entry_date.beginning_of_month
    last_month = (current_month - 1.month).beginning_of_month

    # Get current and previous month totals for each category
    current_totals = stats.month_category_totals(date: current_month)
    previous_totals = stats.month_category_totals(date: last_month)

    trends = calculate_category_trends(current_totals, previous_totals)
    return nil if trends.empty? # Skip if no meaningful trends

    {
      current_totals: current_totals,
      previous_totals: previous_totals,
      trends: trends
    }
  end

  def analyze_budget
    stats = family.budgeting_stats
    return nil unless stats.avg_monthly_income&.positive? || stats.avg_monthly_expenses&.positive?

    current_budget = family.budgets.order(created_at: :desc).first
    {
      avg_monthly_income: stats.avg_monthly_income,
      avg_monthly_expenses: stats.avg_monthly_expenses,
      current_budget: current_budget
    }
  end

  def analyze_savings
    snapshots = family.snapshot_transactions
    return nil unless snapshots && snapshots[:savings_rate_series]&.values&.any?

    {
      savings_rate_series: snapshots[:savings_rate_series],
      income_series: snapshots[:income_series],
      spending_series: snapshots[:spending_series]
    }
  end

  def generate_spending_insights(data)
    return nil unless data && data[:trends].present?
    
    prompt = build_spending_prompt(data)
    response = generate_gpt_response(prompt)
    parse_spending_response(response)
  end

  def generate_budget_insights(data)
    return nil unless data && (data[:avg_monthly_income]&.positive? || data[:avg_monthly_expenses]&.positive?)
    
    prompt = build_budget_prompt(data)
    response = generate_gpt_response(prompt)
    parse_budget_response(response)
  end

  def generate_savings_insights(data)
    # Ensure we have valid savings data
    return nil unless data && 
                     data[:savings_rate_series]&.values&.any? &&
                     data[:income_series]&.values&.any? &&
                     data[:spending_series]&.values&.any?
    
    prompt = build_savings_prompt(data)
    response = generate_gpt_response(prompt)
    parse_savings_response(response)
  end

  def generate_gpt_response(prompt)
    return nil unless prompt.present?
    
    puts "Sending prompt to OpenAI: #{prompt}"
    begin
      response = @client.chat(
        parameters: {
          model: "gpt-4",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7,
          max_tokens: 500
        }
      )
      puts "OpenAI response: #{response.inspect}"
      response.dig("choices", 0, "message", "content")
    rescue => e
      puts "Error calling OpenAI: #{e.message}"
      puts e.backtrace
      nil
    end
  end

  def build_spending_prompt(data)
    # Format the spending data into a clear prompt
    trends = data[:trends].map { |category, trend| 
      "#{category}: #{trend[:change_percent]}% (#{trend[:direction]})" 
    }.join("\n")

    <<~PROMPT
      As a personal finance advisor, analyze these spending trends and provide a key insight focused on long-term financial health:
      
      Monthly Spending Trends:
      #{trends}
      
      Consider:
      1. Patterns that could impact long-term savings goals
      2. Categories with significant changes that need attention
      3. Budget alerts where the user is almost at the limit
      4. Opportunities to optimize spending for better financial outcomes
      
      Format your response as JSON with:
      {
        "title": "Brief, action-oriented insight title",
        "description": "2-3 sentence personalized analysis that explains the impact on long-term goals and provides a specific, actionable recommendation"
      }
    PROMPT
  end

  def build_budget_prompt(data)
    # Convert numeric values to BigDecimal for precise calculations
    avg_monthly_income = data[:avg_monthly_income] ? BigDecimal(data[:avg_monthly_income].to_s) : BigDecimal('0')
    avg_monthly_expenses = data[:avg_monthly_expenses] ? BigDecimal(data[:avg_monthly_expenses].to_s) : BigDecimal('0')

    <<~PROMPT
      As a personal finance advisor, analyze this budget data and suggest a strategic adjustment that could improve long-term financial health:
      
      Financial Overview:
      - Average Monthly Income: #{avg_monthly_income.round(2)}
      - Average Monthly Expenses: #{avg_monthly_expenses.round(2)}
      - Current Budget Allocation: #{data[:current_budget].to_json if data[:current_budget]}
      
      Consider:
      1. The ratio between income and expenses
      2. Potential areas for reallocation to boost savings
      3. Sustainable adjustments that align with long-term goals
      4. Keep suggested adjustments realistic and within 20% of current expenses
      
      Format your response as JSON with:
      {
        "title": "Strategic budget adjustment title",
        "description": "2-3 sentence personalized explanation that ties the adjustment to long-term financial goals and explains the expected impact. Be explicit about whether the amount should be reduced from spending or added to savings.",
        "amount": suggested_monthly_adjustment_amount_that_is_realistic_and_achievable
      }
    PROMPT
  end

  def build_savings_prompt(data)
    savings_series = data[:savings_rate_series]
    return nil unless savings_series&.values&.any?

    # Get the current and average savings rate
    current_rate = savings_series.values.last.value || 0
    avg_rate = savings_series.values.sum { |v| v.value || 0 } / savings_series.values.size

    # Calculate monthly averages for concrete suggestions
    income_series = data[:income_series]
    spending_series = data[:spending_series]
    
    income_avg = income_series.values.sum { |v| v.value.amount } / income_series.values.size
    spending_avg = spending_series.values.sum { |v| v.value.amount } / spending_series.values.size

    <<~PROMPT
      As a personal finance advisor, analyze this savings data and suggest an opportunity to accelerate progress toward long-term financial goals:
      
      Savings Overview:
      - Current Monthly Savings Rate: #{(current_rate * 100).round(1)}%
      - Historical Average Rate: #{(avg_rate * 100).round(1)}%
      - Average Monthly Income: #{income_avg.round(2)}
      - Average Monthly Spending: #{spending_avg.round(2)}
      - Savings Rate Trend: #{current_rate > avg_rate ? "Improving" : "Declining"}
      
      Consider:
      1. The gap between current and optimal savings rates
      2. Realistic opportunities to increase savings based on current income and spending
      3. The impact of suggested changes on long-term goals
      4. Keep suggested adjustments realistic and achievable (within 20% of current spending)
      
      Format your response as JSON with:
      {
        "title": "Goal-oriented savings opportunity",
        "description": "2-3 sentence personalized suggestion that explains both the immediate action and its long-term impact on financial goals. Be specific about where the savings should come from.",
        "amount": suggested_monthly_savings_amount_that_is_realistic_and_achievable
      }
    PROMPT
  end

  def parse_spending_response(response)
    return nil if response.nil?
    JSON.parse(response, symbolize_names: true)
  rescue JSON::ParserError
    puts "Error parsing spending response: #{response}"
    nil
  end

  def parse_budget_response(response)
    return nil if response.nil?
    JSON.parse(response, symbolize_names: true)
  rescue JSON::ParserError
    puts "Error parsing budget response: #{response}"
    nil
  end

  def parse_savings_response(response)
    return nil if response.nil?
    JSON.parse(response, symbolize_names: true)
  rescue JSON::ParserError
    puts "Error parsing savings response: #{response}"
    nil
  end

  def calculate_category_trends(current_totals, previous_totals)
    trends = {}
    
    current_totals.category_totals.each do |current|
      previous = previous_totals.category_totals.find { |p| p.category_id == current.category_id }
      next unless previous && previous.amount.positive?

      # Convert amounts to BigDecimal for more precise calculation
      current_amount = BigDecimal(current.amount.to_s)
      previous_amount = BigDecimal(previous.amount.to_s)
      
      # Calculate percentage change
      change_percent = ((current_amount - previous_amount) / previous_amount * 100).round(1)
      direction = change_percent.positive? ? "increase" : "decrease"

      category = family.categories.find_by(id: current.category_id)
      next unless category
      
      trends[category.name] = {
        change_percent: change_percent.abs,
        direction: direction
      }
    end

    trends
  end
end 