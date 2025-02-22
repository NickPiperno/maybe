# Phase 3: What-If Scenario Simulator (MVP)

This phase implements essential scenario simulation capabilities for basic financial planning and goal setting.

## Goals
- [x] Create core scenario simulation engine
- [ ] Implement basic financial goal tracking
- [x] Build fundamental projection system
- [x] Enable simple scenario comparison

## Features and Tasks

### 1. Basic Scenario Engine

#### Frontend Tasks
- [x] Create simple scenario input form
  - Implemented in `app/views/scenarios/simulate.html.erb`
  - Fields for name, description, income/expense adjustments, savings rate, timeline
- [x] Implement basic variable controls
  - [x] Income changes (percentage adjustment)
  - [x] Expense adjustments (percentage adjustment)
  - [x] Savings rate modifications (0-100%)
- [x] Add fundamental results view
  - Implemented in `app/views/scenarios/show.html.erb`
  - Shows scenario details and simulation results
- [x] Create simple scenario summary
  - Implemented in `app/views/scenarios/_scenario.html.erb`
  - Shows key metrics and adjustments
- [x] Implement basic reset/clear functions
  - Cancel button returns to scenarios list
  - Form resets on submission

#### Backend Tasks
- [x] Create core simulation engine
  - Implemented in `app/models/scenario_simulator.rb`
  - Uses real family transaction data for baseline calculations
  - Handles monthly projections and calculations
- [x] Implement basic variable processing
  - Validates adjustments and rates in `app/models/scenario.rb`
  - Processes changes in `ScenarioSimulator`
- [x] Add fundamental calculations
  - [x] Net income projection (with adjustments)
  - [x] Savings accumulation (monthly and total)
  - [x] Basic debt impact (via AI analysis)
- [x] Create simple result storage
  - Scenarios table with required fields
  - Belongs to Family model
- [x] Implement essential validation
  - Timeline: 1-60 months
  - Required name and timeline
  - Numeric validations for adjustments

### 2. Core Financial Goals

#### Frontend Tasks
- [ ] Design basic goal input interface
- [x] Create simple timeline selector
  - [x] Short-term (1-12 months)
  - [x] Medium-term (1-5 years)
- [ ] Add basic milestone creation
- [x] Implement simple progress view
  - Added feasibility score visualization
  - Progress tracking through AI analysis
- [x] Create fundamental goal summary
  - AI-driven recommendations and impact analysis
  - Risk assessment and mitigation strategies

#### Backend Tasks
- [x] Create basic goal planning engine
  - Implemented in `ScenarioAnalyzer`
  - AI-powered feasibility assessment
- [x] Implement essential timeline calculations
  - Monthly projections with AI insights
- [ ] Add core milestone tracking
- [x] Create simple progress calculations
  - Feasibility scoring (0-100)
  - Target vs. current state analysis
- [x] Implement basic goal validation
  - AI-driven validation of scenario feasibility
  - Risk assessment and mitigation suggestions

### 3. Essential Projections

#### Frontend Tasks
- [x] Create basic projection dashboard
  - Monthly projections table in scenario view
  - AI analysis panel with recommendations
- [x] Implement fundamental chart views
  - [x] Feasibility score gauge
  - [ ] Monthly projection charts
  - [x] Basic trend indicators via AI analysis
- [x] Add simple data table view
  - Shows monthly income, expenses, savings, and rates
  - Integrates with real family data
- [x] Create essential comparison view
  - Basic scenario list with key metrics
  - AI-driven impact analysis
- [ ] Implement basic print layout

#### Backend Tasks
- [x] Create core projection engine
  - Monthly projections in `ScenarioSimulator`
  - AI analysis in `ScenarioAnalyzer`
- [x] Implement basic calculation service
  - Uses real family transaction data
  - Handles income, expense, and savings calculations
- [x] Add essential data aggregation
  - Calculates totals and averages
  - Integrates with family's historical data
- [x] Create simple comparison logic
  - Shows adjustments and impact
  - AI-driven feasibility assessment
- [ ] Implement fundamental caching

### 4. Basic Impact Analysis

#### Frontend Tasks
- [x] Design simple impact summary
  - Shows key metrics and changes
  - Displays AI-driven insights
- [x] Create basic adjustment controls
  - [x] Income adjustments
  - [x] Expense modifications
  - [x] Savings changes
- [x] Implement essential results view
  - Shows projected outcomes
  - Displays AI analysis and recommendations
- [x] Add fundamental alerts
  - Risk assessment from AI analysis
  - Feasibility warnings
- [x] Create simple recommendations
  - AI-generated action items
  - Impact analysis for each recommendation

#### Backend Tasks
- [x] Create core analysis engine
  - Implemented in `ScenarioAnalyzer`
  - Uses GPT-4 for intelligent analysis
- [x] Implement basic calculations
  - Monthly and cumulative projections
  - Based on real family data
- [x] Add essential validation rules
  - Model validations for inputs
  - AI-driven feasibility checks
- [x] Create simple alert triggers
  - Risk identification via AI
  - Feasibility score thresholds
- [x] Implement basic recommendation logic
  - AI-generated recommendations
  - Type-specific insights (income/expense/savings)

## Technical Considerations

### Data Models Created
- [x] Create `Scenario` model (basic)
  - Belongs to Family
  - Core attributes and validations
- [x] Create `ScenarioAnalyzer` model (core)
  - AI-powered analysis engine
  - Integrates with OpenAI GPT-4
- [ ] Add `FinancialGoal` model (essential)
- [x] Create `Projection` model (core)
  - Implemented as part of ScenarioSimulator
  - Uses real family transaction data

### Background Jobs
- [ ] Basic scenario calculations
- [ ] Essential goal updates
- [ ] Core projection generation

### Caching Strategy
- [ ] Basic scenario caching
- [ ] Essential projection caching
- [ ] Core calculation results caching

### Security Considerations
- [x] Basic scenario privacy
  - Scenarios belong to family
  - Proper authorization checks
- [x] Essential data protection
  - Secure routes and controllers
  - Safe handling of financial data
- [x] Core access controls
  - Family-scoped access
  - AI analysis security

## Dependencies
- [x] AI Budget Recommendations (Phase 2)
  - Leveraged for scenario analysis
  - Integrated AI recommendation patterns
- [x] Enhanced Transaction Dashboard (Phase 1)
  - Used for baseline calculations
  - Real transaction data integration
- [x] Current data models
  - Family model integration
  - Transaction data access

## Migration Strategy
- [x] 1. Deploy core simulation engine
- [x] 2. Enable AI analysis
- [x] 3. Add essential projections
- [x] 4. Implement basic analysis

## TODOs and Next Steps
1. Add monthly projection charts for visual trends
2. Implement caching for AI analysis results
3. Create goal tracking system with milestones
4. Add export functionality for scenarios
5. Enhance AI recommendations with more context
6. Add comparison view between multiple scenarios 