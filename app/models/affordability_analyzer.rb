class AffordabilityAnalyzer
  attr_reader :family, :goal_type

  MORTGAGE_RATE = 6.8  # This should be fetched from an API in production
  PROPERTY_TAX_RATE = 0.011  # Average property tax rate, should be location-specific
  HOME_INSURANCE_RATE = 0.0035  # Average home insurance rate
  MAINTENANCE_RATE = 0.01  # 1% annual maintenance cost
  DOWN_PAYMENT_OPTIONS = [0.035, 0.05, 0.10, 0.20]  # 3.5% (FHA), 5%, 10%, 20%
  DTI_RATIO_MAX = 0.43  # Maximum debt-to-income ratio (43% is common)
  GDS_RATIO_MAX = 0.32  # Maximum Gross Debt Service ratio (housing costs / income)
  TDS_RATIO_MAX = 0.40  # Maximum Total Debt Service ratio (all debt payments / income)
  VACATION_SAVINGS_MONTHS = 12  # Target months to save for vacation

  def initialize(family, goal_type)
    @family = family
    @goal_type = goal_type
  end

  def analyze
    begin
      Rails.logger.info "Starting financial data collection..."
      # Collect core financial data
      financial_data = collect_financial_data
      Rails.logger.info "Financial data collected: #{financial_data.inspect}"
      return financial_data if financial_data[:error].present?

      Rails.logger.info "Generating scenarios..."
      # Generate scenarios based on goal type
      scenarios = generate_scenarios(financial_data)
      Rails.logger.info "Scenarios generated: #{scenarios.inspect}"

      Rails.logger.info "Generating AI recommendations..."
      # Generate AI recommendations based on goal type
      recommendations = generate_ai_recommendations(scenarios: scenarios, financial_data: financial_data)
      Rails.logger.info "AI recommendations generated: #{recommendations.inspect}"
      
      recommendations
    rescue => e
      Rails.logger.error "Error in affordability analysis: #{e.class} - #{e.message}"
      Rails.logger.error "Error occurred at:"
      Rails.logger.error e.backtrace.join("\n")
      {
        error: "analysis_error",
        message: "An error occurred while analyzing your financial data. Please try again."
      }
    end
  end

  private

  def collect_financial_data
    # Get current assets and liabilities
    assets = calculate_total_assets
    liabilities = calculate_total_liabilities
    savings = calculate_savings
    investments = calculate_investments
    monthly_debt_payments = calculate_monthly_debt_payments
    net_worth = assets - liabilities

    # Check for existing home ownership
    current_home = family.accounts.active.where(accountable_type: 'Property')
                        .where("name ILIKE ? OR name ILIKE ?", "%primary%", "%home%")
                        .first
    
    current_home_data = if current_home
      mortgage = family.accounts.active.where(accountable_type: 'Loan')
                      .where("name ILIKE ?", "%mortgage%")
                      .first
      
      {
        value: current_home.balance_money.exchange_to(family.currency).amount,
        mortgage_balance: mortgage&.balance_money&.exchange_to(family.currency)&.amount || 0,
        equity: current_home.balance_money.exchange_to(family.currency).amount - 
               (mortgage&.balance_money&.exchange_to(family.currency)&.amount || 0),
        monthly_payment: mortgage&.accountable&.monthly_payment&.exchange_to(family.currency)&.amount || 0
      }
    end

    # Create analysis period
    analysis_period = Period.new.tap do |p|
      def p.date_range
        6.months.ago.to_date..Date.current
      end
    end

    # Get transactions for analysis
    candidate_entries = family.entries.account_transactions.incomes_and_expenses
                             .where('account_entries.date >= ?', analysis_period.date_range.begin)
                             .where('account_entries.date <= ?', analysis_period.date_range.end)

    # Get daily totals and build snapshot
    daily_totals = Account::Entry.daily_totals(candidate_entries, family.currency, period: analysis_period)
    snapshot = build_snapshot(daily_totals)

    return { error: "insufficient_data", message: "Unable to analyze your financial data. Please ensure you have sufficient transaction history." } unless snapshot[:income_series]&.values&.any? && snapshot[:spending_series]&.values&.any?

    # Calculate monthly averages
    monthly_income = calculate_average(snapshot[:income_series])
    monthly_expenses = calculate_average(snapshot[:spending_series])
    monthly_savings = monthly_income - monthly_expenses

    # Calculate potential debt consolidation savings
    credit_card_accounts = family.accounts.active.where(accountable_type: 'CreditCard')
    total_credit_card_debt = credit_card_accounts.sum { |cc| cc.balance_money.exchange_to(family.currency).amount }
    potential_monthly_savings = calculate_debt_consolidation_savings(total_credit_card_debt)

    {
      monthly_income: monthly_income,
      monthly_expenses: monthly_expenses,
      monthly_savings: monthly_savings,
      assets: assets,
      liabilities: liabilities,
      savings: savings,
      investments: investments,
      monthly_debt_payments: monthly_debt_payments,
      net_worth: net_worth,
      potential_monthly_savings: potential_monthly_savings,
      total_credit_card_debt: total_credit_card_debt,
      adjusted_monthly_savings: monthly_savings + potential_monthly_savings,
      current_home: current_home_data  # Add current home data to the financial data
    }
  end

  def generate_scenarios(financial_data)
    Rails.logger.info "Generating scenarios for goal_type: #{goal_type}"
    Rails.logger.info "Financial data for scenarios: #{financial_data.inspect}"

    scenarios = case goal_type.to_sym
    when :house
      Rails.logger.info "Generating house scenarios..."
      generate_house_scenarios(financial_data)
    when :vacation
      Rails.logger.info "Generating vacation scenarios..."
      generate_vacation_scenarios(financial_data)
    else
      Rails.logger.error "Invalid goal type: #{goal_type}"
      []
    end

    if scenarios.nil? || scenarios.empty?
      Rails.logger.error "Generated scenarios were nil or empty"
      return []
    end

    Rails.logger.info "Generated #{scenarios.length} scenarios"
    scenarios
  end

  def generate_house_scenarios(data)
    # Calculate maximum monthly payment based on both DTI and GDS
    max_payment_dti = data[:monthly_income] * DTI_RATIO_MAX - (data[:monthly_debt_payments] - data[:potential_monthly_savings])
    max_payment_gds = data[:monthly_income] * GDS_RATIO_MAX
    max_monthly_payment = [max_payment_dti, max_payment_gds].min

    # Calculate total available funds for down payment
    total_available_funds = data[:savings] + (data[:investments] * 0.7) # Assuming we can use 70% of investments to be conservative
      
    # Only generate scenarios for the most relevant down payment options
    relevant_options = if total_available_funds < 10_000
      [0.035] # If low funds, only show FHA option
    elsif total_available_funds < 50_000
      [0.035, 0.05] # If moderate funds, show FHA and 5%
    else
      [0.05, 0.20] # If good funds, show 5% and 20%
    end

    # Generate scenarios for selected down payment options
    relevant_options.map do |down_payment_rate|
      max_price = calculate_max_house_price(
        max_monthly_payment: max_monthly_payment,
        down_payment_rate: down_payment_rate
      )

      down_payment_amount = max_price * down_payment_rate
      months_to_down_payment = if down_payment_amount <= total_available_funds
        0
      elsif data[:adjusted_monthly_savings] > 0
        ((down_payment_amount - total_available_funds) / data[:adjusted_monthly_savings]).ceil
      else
        Float::INFINITY
      end

      {
        down_payment_percentage: (down_payment_rate * 100).round(1),
        down_payment_amount: down_payment_amount,
        available_funds: {
          total_available: total_available_funds
        },
        additional_savings_needed: [down_payment_amount - total_available_funds, 0].max,
        max_house_price: max_price,
        monthly_payment: calculate_monthly_payment(max_price, down_payment_rate),
        months_to_save_down_payment: months_to_down_payment,
        debt_ratios: {
          dti: calculate_dti_ratio(data[:monthly_income], data[:monthly_debt_payments] - data[:potential_monthly_savings]),
          gds: calculate_gds_ratio(data[:monthly_income], calculate_monthly_payment(max_price, down_payment_rate))
        }
      }
    end
  end

  def generate_vacation_scenarios(data)
    # Calculate total available funds from savings and a portion of investments
    available_funds = data[:savings] + (data[:investments] * 0.05)  # Consider 5% of investments for vacation
    current_savings_capacity = data[:monthly_savings]
    
    # Calculate conservative budget based on available funds
    # Use at most 10% of available funds for immediate options, capped at $1000
    immediate_budget = [available_funds * 0.10, 1000].min
    
    # Calculate minimum viable budget for local experiences
    min_staycation_budget = [available_funds * 0.05, 500].min  # 5% of funds or $500, whichever is lower
    
    # Generate scenarios based on financial situation
    scenarios = []

    # Always include a conservative immediate option if there are any funds
    if available_funds > 0
      scenarios << {
        budget: immediate_budget,
        savings_per_month: 0,
        months_to_save: 0,
        type: "immediate_modest",
        description: "Conservative local experience using a small portion of savings"
      }

      # Add a staycation option
      scenarios << {
        budget: min_staycation_budget,
        savings_per_month: 0,
        months_to_save: 0,
        type: "staycation",
        description: "Budget-friendly staycation focusing on local activities"
      }
    end

    # If monthly savings is positive, show future options
    if current_savings_capacity > 0
      future_savings = current_savings_capacity * 6  # 6 months of savings
      future_budget = [future_savings + (available_funds * 0.15), 2000].min

      scenarios << {
        budget: future_budget,
        savings_per_month: current_savings_capacity,
        months_to_save: 6,
        type: "future_planned",
        description: "Planned vacation combining savings and careful budgeting"
      }
    end

    # Calculate potential savings from expense optimization
    potential_savings = data[:monthly_expenses] * 0.1  # Assume 10% expense reduction possible
    
    if potential_savings > 0
      optimized_budget = [min_staycation_budget + (potential_savings * 6), 1500].min
      scenarios << {
        budget: optimized_budget,
        savings_per_month: potential_savings,
        months_to_save: 6,
        type: "expense_optimized",
        description: "Vacation plan achievable through expense optimization"
      }
    end

    # Ensure we always have at least one scenario
    if scenarios.empty? && available_funds > 0
      scenarios << {
        budget: min_staycation_budget,
        savings_per_month: 0,
        months_to_save: 0,
        type: "minimal_staycation",
        description: "Very conservative local experience focusing on free and low-cost activities"
      }
    end

    scenarios
  end

  def generate_ai_recommendations(scenarios:, financial_data:)
    # Validate scenarios
    if scenarios.nil? || scenarios.empty?
      Rails.logger.error "Cannot generate recommendations: scenarios are nil or empty"
      return generate_fallback_recommendations(scenarios, financial_data)
    end

    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    # Define system message based on goal type
    system_message = if goal_type.to_sym == :house
      "You are a mortgage broker and financial advisor. Analyze the provided scenarios and respond with a JSON object containing your recommendations."
    else
      "You are a practical financial advisor focused on realistic vacation plans. Analyze the provided scenarios and respond with a JSON object containing your recommendations."
    end

    begin
      # Generate the appropriate prompt
      prompt = case goal_type.to_sym
      when :house
        generate_house_prompt(scenarios, financial_data)
      when :vacation
        generate_vacation_prompt(scenarios, financial_data)
      end

      # Log the input parameters
      Rails.logger.info "OpenAI API Input Parameters:"
      Rails.logger.info "Goal Type: #{goal_type}"
      Rails.logger.info "System Message: #{system_message}"
      Rails.logger.info "Temperature: #{goal_type.to_sym == :house ? 0.7 : 0.3}"
      Rails.logger.info "Full Prompt:\n#{prompt}"

      # Make the API call with updated parameters
      response = client.chat(
        parameters: {
          model: "gpt-4-1106-preview",  # Use the latest model that better handles JSON
          messages: [
            { role: "system", content: system_message },
            { role: "user", content: prompt }
          ],
          temperature: goal_type.to_sym == :house ? 0.7 : 0.3,
          response_format: { type: "json_object" }
        }
      )

      # Log the raw response for debugging
      Rails.logger.info "OpenAI API Raw Response: #{response.inspect}"

      # Extract and validate the content
      content = response.dig("choices", 0, "message", "content")
      
      if content.nil?
        Rails.logger.error "OpenAI API returned nil content"
        return generate_fallback_recommendations(scenarios, financial_data)
      end

      # Parse and validate JSON
      begin
        parsed_response = JSON.parse(content, symbolize_names: true)
        Rails.logger.info "Successfully parsed JSON response: #{parsed_response.inspect}"
        parsed_response
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse OpenAI response as JSON: #{e.message}"
        Rails.logger.error "Raw content that failed to parse: #{content}"
        generate_fallback_recommendations(scenarios, financial_data)
      end
    rescue Faraday::BadRequestError => e
      Rails.logger.error "OpenAI API BadRequestError: #{e.message}"
      Rails.logger.error "Request parameters that caused error:"
      Rails.logger.error "System Message: #{system_message}"
      Rails.logger.error "Prompt: #{prompt}"
      generate_fallback_recommendations(scenarios, financial_data)
    rescue => e
      Rails.logger.error "Error generating #{goal_type} recommendations: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      generate_fallback_recommendations(scenarios, financial_data)
    end
  end

  def generate_house_prompt(scenarios, data)
    # Add current home ownership context to the prompt
    current_home_context = if data[:current_home]
      <<~HOME
        Current Home Situation:
        - Current Home Value: $#{data[:current_home][:value].round}
        - Remaining Mortgage: $#{data[:current_home][:mortgage_balance].round}
        - Available Equity: $#{data[:current_home][:equity].round}
        - Current Monthly Payment: $#{data[:current_home][:monthly_payment].round}

      HOME
    else
      "Current Home Situation: First-time homebuyer (no existing property)\n\n"
    end

    <<~PROMPT
      As an expert mortgage broker and financial advisor, analyze these scenarios and provide detailed, actionable recommendations.
      Focus on what the user can do RIGHT NOW with their current financial situation, while also providing steps for improvement.
      If a scenario is viable now, explain exactly how to proceed. If not, provide specific steps to make it viable.

      #{current_home_context}
      Financial Summary:
      - Monthly Income: $#{data[:monthly_income].round}
      - Monthly Expenses: $#{data[:monthly_expenses].round}
      - Monthly Savings: $#{data[:monthly_savings].round}
      - Available Savings: $#{data[:savings].round}
      - Available Investments: $#{data[:investments].round}
      - Monthly Debt: $#{data[:monthly_debt_payments].round}
      - Total Assets: $#{data[:assets].round}
      - Total Liabilities: $#{data[:liabilities].round}
      - Net Worth: $#{data[:net_worth].round}

      Available Home Buying Scenarios:
      #{scenarios.map { |s| """
      #{s[:down_payment_percentage]}% Down Payment Scenario:
      - House Price: $#{s[:max_house_price].round}
      - Down Payment: $#{s[:down_payment_amount].round}
      - Monthly Payment: $#{s[:monthly_payment].round}
      - Available Funds:
        - Savings: $#{s[:available_funds][:total_available].round}
      - Additional Savings Needed: $#{s[:additional_savings_needed].round}
      - DTI: #{(s[:debt_ratios][:dti] * 100).round}%
      - GDS: #{(s[:debt_ratios][:gds] * 100).round}%
      """}.join("\n")}

      For each scenario, analyze:
      1. Is this scenario viable right now? Why or why not?
      2. What specific steps would make this scenario viable?
      3. What are the pros and cons of this scenario?
      4. What is the recommended timeline for this scenario?

      Provide a JSON response with:
      {
        "financial_health": {
          "status": "strong|moderate|needs_improvement",
          "summary": "Brief assessment of overall financial health",
          "key_metrics": {
            "savings_rate": "Monthly savings as percentage of income",
            "debt_burden": "Debt payments as percentage of income",
            "liquidity": "Months of expenses covered by liquid assets"
          }
        },
        "scenarios_analysis": [
          {
            "down_payment_percentage": "Percentage for this scenario",
            "house_price": "Maximum house price for this scenario",
            "monthly_payment": "Total monthly payment including taxes and insurance",
            "is_viable_now": true|false,
            "viability_explanation": "Detailed explanation of why this scenario is or isn't viable",
            "required_steps": [
              {
                "step": "Specific action needed",
                "target": "Numerical target to achieve",
                "timeline": "Expected timeline",
                "priority": "high|medium|low"
              }
            ],
            "pros": ["List of advantages for this scenario"],
            "cons": ["List of disadvantages for this scenario"]
          }
        ],
        "recommended_scenario": {
          "down_payment_percentage": "Most recommended down payment option",
          "house_price": "Recommended house price",
          "monthly_payment": "Expected monthly payment",
          "explanation": "Detailed explanation of why this scenario is recommended",
          "immediate_next_steps": ["List of specific actions to take right now"]
        },
        "improvement_steps": [
          {
            "title": "Step title",
            "description": "Specific action with numerical targets",
            "impact": "Expected impact with numbers",
            "timeline": "Estimated timeline",
            "priority": "high|medium|low"
          }
        ],
        "risks": [
          {
            "type": "Risk type",
            "description": "Detailed risk description",
            "mitigation": "Specific mitigation strategy"
          }
        ]
      }
    PROMPT
  end

  def generate_vacation_prompt(scenarios, data)
    <<~PROMPT
      As a financial advisor, analyze these vacation scenarios:

      Current Financial State:
      - Monthly Income: $#{data[:monthly_income].round(2)}
      - Monthly Expenses: $#{data[:monthly_expenses].round(2)}
      - Monthly Savings: $#{data[:monthly_savings].round(2)}
      - Total Assets: $#{data[:assets].round(2)}
      - Total Liabilities: $#{data[:liabilities].round(2)}
      - Net Worth: $#{data[:net_worth].round(2)}

      Available Scenarios:
      #{scenarios.map { |s| """
        Scenario:
        - Vacation Budget: $#{s[:budget].round(2)}
        - Monthly Savings Needed: $#{s[:savings_per_month].round(2)}
        - Months to Save: #{s[:months_to_save]}
      """}.join("\n")}

      Provide a detailed analysis in JSON format with:
      1. Overall financial health assessment
      2. Recommended vacation budget based on current savings capacity
      3. Detailed steps to increase vacation budget with specific targets
      4. Suggested vacation types within budget and aspirational options
      5. Risks and considerations

      Format your response as JSON with:
      {
        "financial_health": {
          "status": "strong|moderate|needs_improvement",
          "summary": "Brief assessment of overall financial health",
          "key_metrics": {
            "savings_rate": "Monthly savings as percentage of income",
            "debt_burden": "Debt payments as percentage of income",
            "liquidity": "Months of expenses covered by liquid assets"
          }
        },
        "recommended_budget": {
          "amount": "Recommended vacation budget",
          "monthly_savings": "Monthly savings needed",
          "explanation": "Why this budget is recommended",
          "timeline": "When this vacation could happen"
        },
        "vacation_suggestions": [
          {
            "type": "Type of vacation",
            "estimated_cost": "Estimated cost",
            "description": "What's included",
            "savings_required": "Additional savings needed",
            "timeline": "When this could be achievable"
          }
        ],
        "improvement_steps": [
          {
            "title": "Step title",
            "description": "Specific action with numerical target",
            "current_amount": "Current amount or rate",
            "target_amount": "Target amount or rate to achieve",
            "monthly_impact": "Monthly dollar impact",
            "timeline": "Expected timeline",
            "priority": "high|medium|low",
            "tracking_metric": "How to measure progress"
          }
        ]
      }
    PROMPT
  end

  def generate_fallback_recommendations(scenarios, data)
    case goal_type
    when :house
      # Default values for when no scenarios are available
      default_scenario = {
        max_house_price: 0,
        down_payment_percentage: 20,
        monthly_payment: 0,
        additional_savings_needed: data[:monthly_income] * 12 * 0.2  # Suggest saving 20% of annual income
      }
      scenario = scenarios.first || default_scenario

      {
        financial_health: {
          status: "needs_review",
          summary: "Basic financial assessment available",
          key_metrics: {
            savings_rate: "#{(data[:monthly_savings] / data[:monthly_income] * 100).round(1)}%",
            debt_burden: "#{(data[:monthly_debt_payments] / data[:monthly_income] * 100).round(1)}% of monthly income",
            liquidity: "#{(data[:liquid_assets] / data[:monthly_expenses]).round(1)} months of expenses covered"
          }
        },
        recommended_scenario: {
          down_payment_percentage: "Not applicable",
          max_house_price: "Not applicable",
          monthly_payment: "Not applicable",
          explanation: "Basic assessment: With current savings rate of #{(data[:monthly_savings] / data[:monthly_income] * 100).round(1)}%, focus on building savings for down payment.",
          contingencies: ["Improve savings rate", "Build emergency fund", "Reduce monthly expenses"]
        },
        improvement_steps: [
          {
            title: "Build Savings",
            description: "Focus on increasing monthly savings for down payment",
            impact: "Need to save at least $#{scenario[:additional_savings_needed].round(2)}",
            timeline: "6-12 months",
            priority: "high"
          }
        ],
        risks: [
          {
            type: "Savings Risk",
            description: "Current savings rate may make home ownership challenging",
            mitigation: "Focus on building emergency fund and down payment savings"
          }
        ]
      }
    when :vacation
      # Calculate available funds
      available_funds = data[:savings] + (data[:investments] * 0.05)  # Consider 5% of investments
      
      # Calculate conservative budgets
      immediate_budget = [available_funds * 0.10, 1000].min  # 10% of funds, max $1000
      staycation_budget = [available_funds * 0.05, 500].min  # 5% of funds, max $500
      
      # Calculate current financial capacity
      current_savings_capacity = data[:monthly_savings]
      potential_expense_reduction = data[:monthly_expenses] * 0.1  # 10% expense reduction potential

      # Generate vacation suggestions based on available budgets
      vacation_suggestions = []
      
      if available_funds > 0
        vacation_suggestions << {
          type: "Local Experiences Package",
          estimated_cost: staycation_budget,
          description: "Curated local experiences focusing on free and low-cost activities, including parks, community events, and affordable entertainment",
          savings_required: 0,
          timeline: "Immediate"
        }

        if immediate_budget > staycation_budget
          vacation_suggestions << {
            type: "Weekend Getaway Package",
            estimated_cost: immediate_budget,
            description: "Short local trip with modest accommodations and selected activities",
            savings_required: 0,
            timeline: "Within 1 month"
          }
        end
      end

      if current_savings_capacity <= 0
        improvement_message = "While current spending exceeds income, we can still enjoy local experiences using a small portion of savings while working on improving financial health."
        budget_explanation = "Focus on low-cost local experiences while building savings through expense optimization. Limited use of existing savings for immediate enjoyment."
      else
        improvement_message = "Current savings rate allows for modest vacation planning while maintaining financial responsibility."
        budget_explanation = "Balanced approach combining minimal use of savings with future planning through careful budgeting."
      end

      {
        financial_health: {
          status: current_savings_capacity <= 0 ? "needs_improvement" : "moderate",
          summary: improvement_message,
          key_metrics: {
            savings_rate: "#{(data[:monthly_savings] / data[:monthly_income] * 100).round(1)}%",
            debt_burden: "#{(data[:monthly_debt_payments] / data[:monthly_income] * 100).round(1)}% of monthly income",
            liquidity: "#{(data[:savings] / data[:monthly_expenses]).round(1)} months of expenses covered"
          }
        },
        recommended_budget: {
          amount: staycation_budget,
          monthly_savings: [potential_expense_reduction, 0].max,
          explanation: budget_explanation,
          timeline: "Start with local experiences now, plan for bigger trips after improving financial health"
        },
        vacation_suggestions: vacation_suggestions,
        improvement_steps: [
          {
            title: "Create Modest Entertainment Fund",
            description: "Set aside a very small portion of savings for local experiences",
            current_amount: 0,
            target_amount: staycation_budget,
            monthly_impact: staycation_budget / 3,  # Spread over 3 months
            timeline: "Start immediately",
            priority: "medium",
            tracking_metric: "Monthly entertainment spending"
          },
          {
            title: "Optimize Monthly Expenses",
            description: "Review and reduce non-essential monthly expenses",
            current_amount: data[:monthly_expenses],
            target_amount: data[:monthly_expenses] * 0.9,  # 10% reduction target
            monthly_impact: potential_expense_reduction,
            timeline: "1-2 months",
            priority: "high",
            tracking_metric: "Monthly essential vs non-essential expenses"
          },
          {
            title: "Build Emergency Fund",
            description: "Prioritize emergency savings before vacation planning",
            current_amount: data[:savings],
            target_amount: data[:monthly_expenses] * 3,  # 3 months expenses
            monthly_impact: potential_expense_reduction,
            timeline: "3-6 months",
            priority: "high",
            tracking_metric: "Emergency fund growth"
          }
        ]
      }
    end
  end

  def build_snapshot(daily_totals)
    spending = []
    income = []
    savings = []
    
    daily_totals.each do |r|
      spending << {
        date: r.date,
        value: Money.new(r.spending, family.currency)
      }

      income << {
        date: r.date,
        value: Money.new(r.income, family.currency)
      }

      savings << {
        date: r.date,
        value: r.income != 0 ? ((r.income - r.spending) / r.income) : 0.to_d
      }
    end

    {
      income_series: TimeSeries.new(income, favorable_direction: "up"),
      spending_series: TimeSeries.new(spending, favorable_direction: "down"),
      savings_rate_series: TimeSeries.new(savings, favorable_direction: "up")
    }
  end

  def calculate_debt_consolidation_savings(total_credit_card_debt)
    return 0 if total_credit_card_debt <= 0
    
    # Calculate potential savings from debt consolidation
    current_cc_payments = total_credit_card_debt * 0.03  # Current minimum payments
    consolidated_payment = estimate_loan_payment(total_credit_card_debt, 0.07, 60)  # 7% personal loan over 5 years
    current_cc_payments - consolidated_payment
  end

  # Keep existing helper methods unchanged
  def calculate_total_assets
    family.accounts.active.assets.sum do |account|
      account.balance_money.exchange_to(family.currency).amount
    end
  end

  def calculate_total_liabilities
    family.accounts.active.liabilities.sum do |account|
      account.balance_money.exchange_to(family.currency).amount
    end
  end

  def calculate_liquid_assets
    family.accounts.active.where(accountable_type: ['Depository', 'Investment']).sum do |account|
      account.balance_money.exchange_to(family.currency).amount
    end
  end

  def calculate_monthly_debt_payments
    monthly_payments = 0

    family.accounts.active.liabilities.each do |account|
      case account.accountable_type
      when 'CreditCard'
        monthly_payments += account.balance_money.exchange_to(family.currency).amount * 0.03
      when 'Loan'
        if account.accountable.rate_type == 'fixed' && account.accountable.monthly_payment.present?
          monthly_payments += account.accountable.monthly_payment.exchange_to(family.currency).amount
        else
          monthly_payments += estimate_loan_payment(
            account.balance_money.exchange_to(family.currency).amount,
            account.accountable.interest_rate || 0.05,
            account.accountable.term_months || 360
          )
        end
      end
    end

    monthly_payments
  end

  def calculate_average(series)
    return 0 unless series&.values&.any?
    daily_total = series.values.sum { |v| v.value.amount }
    daily_average = daily_total / series.values.size
    daily_average * 30.44  # Average days in a month (365.25/12)
  end

  def calculate_max_house_price(max_monthly_payment:, down_payment_rate:)
    r = MORTGAGE_RATE / 12 / 100
    n = 30 * 12
    other_monthly_costs_rate = (PROPERTY_TAX_RATE + HOME_INSURANCE_RATE + MAINTENANCE_RATE) / 12
    max_loan = max_monthly_payment * (1 - other_monthly_costs_rate) * ((1 - (1 + r)**-n) / r)
    max_loan / (1 - down_payment_rate)
  end

  def calculate_monthly_payment(house_price, down_payment_rate)
    loan_amount = house_price * (1 - down_payment_rate)
    r = MORTGAGE_RATE / 12 / 100
    n = 30 * 12
    monthly_pi = loan_amount * (r * (1 + r)**n) / ((1 + r)**n - 1)
    monthly_others = house_price * (PROPERTY_TAX_RATE + HOME_INSURANCE_RATE + MAINTENANCE_RATE) / 12
    monthly_pi + monthly_others
  end

  def calculate_dti_ratio(monthly_income, monthly_debt_payments)
    return 0 if monthly_income.zero?
    monthly_debt_payments / monthly_income
  end

  def calculate_gds_ratio(monthly_income, housing_payment)
    return 0 if monthly_income.zero?
    housing_payment / monthly_income
  end

  def calculate_tds_ratio(monthly_income, monthly_debt_payments, housing_payment)
    return 0 if monthly_income.zero?
    (monthly_debt_payments + housing_payment) / monthly_income
  end

  def estimate_loan_payment(principal, annual_rate, term_months)
    return 0 if principal.zero?
    monthly_rate = annual_rate / 12
    if monthly_rate.zero?
      principal / term_months
    else
      principal * (monthly_rate * (1 + monthly_rate)**term_months) / ((1 + monthly_rate)**term_months - 1)
    end
  end

  def calculate_savings
    family.accounts.active.where(accountable_type: 'Depository').sum do |account|
      account.balance_money.exchange_to(family.currency).amount
    end
  end

  def calculate_investments
    family.accounts.active.where(accountable_type: 'Investment').sum do |account|
      account.balance_money.exchange_to(family.currency).amount
    end
  end
end 