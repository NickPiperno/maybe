# Affordability Analyzer Bug Fix

## Issue
The affordability analyzer is incorrectly reporting "insufficient transaction history" even when 6 months of transaction data exists. This is due to an ambiguous column reference in the SQL queries when joining multiple tables.

## Problem Details
1. The error occurs in the `AffordabilityAnalyzer#analyze` method when checking transaction history
2. The issue manifests when querying income and expense entries with date filters across joined tables
3. Current error:
```sql
ERROR: column reference "date" is ambiguous
LINE 1: ... inflow_accounts.accountable_type = 'Loan')) AND (date >= $3...
```

## Required Fixes

### 1. Update Query Scopes
In `app/models/account/entry.rb`, update the following scopes to explicitly reference the `account_entries` table:

```ruby
scope :incomes_and_expenses, -> {
  joins("INNER JOIN account_transactions ON account_transactions.id = account_entries.entryable_id AND account_entries.entryable_type = 'Account::Transaction'")
    .joins("LEFT JOIN transfers ON transfers.inflow_transaction_id = account_transactions.id OR transfers.outflow_transaction_id = account_transactions.id")
    .joins("LEFT JOIN account_transactions inflow_txns ON inflow_txns.id = transfers.inflow_transaction_id")
    .joins("LEFT JOIN account_entries inflow_entries ON inflow_entries.entryable_id = inflow_txns.id AND inflow_entries.entryable_type = 'Account::Transaction'")
    .joins("LEFT JOIN accounts inflow_accounts ON inflow_accounts.id = inflow_entries.account_id")
    .where("transfers.id IS NULL OR transfers.status = 'rejected' OR (account_entries.amount > 0 AND inflow_accounts.accountable_type = 'Loan')")
}
```

### 2. Update Date Filters
In `app/models/affordability_analyzer.rb`, update the date filtering to explicitly reference the `account_entries` table:

```ruby
candidate_entries = family.entries.account_transactions.incomes_and_expenses
                         .where('account_entries.date >= ?', analysis_period.date_range.begin)
                         .where('account_entries.date <= ?', analysis_period.date_range.end)
```

### 3. Update Daily Totals Query
In `app/models/account/entry.rb`, update the `daily_totals` method to use explicit table references:

```ruby
def self.daily_totals(entries, currency, period: Period.last_30_days)
  select(
    "gs.date",
    "COALESCE(SUM(converted_amount) FILTER (WHERE converted_amount > 0), 0) AS spending",
    "COALESCE(SUM(-converted_amount) FILTER (WHERE converted_amount < 0), 0) AS income"
  )
    .from(entries.with_converted_amount(currency), :e)
    .joins(sanitize_sql([
      "RIGHT JOIN generate_series(?, ?, interval '1 day') AS gs(date) ON e.date = gs.date",
      period.date_range.first,
      period.date_range.last
    ]))
    .group("gs.date")
end
```

## Testing Steps
After implementing these changes:
1. Verify transaction counts:
```ruby
family = Family.last
puts "Total entries in last 6 months: #{family.entries.where('account_entries.date >= ?', 6.months.ago).count}"
puts "Income/Expense entries in last 6 months: #{family.entries.account_transactions.incomes_and_expenses.where('account_entries.date >= ?', 6.months.ago).count}"
puts "Income entries: #{family.entries.account_transactions.incomes.where('account_entries.date >= ?', 6.months.ago).count}"
puts "Expense entries: #{family.entries.account_transactions.expenses.where('account_entries.date >= ?', 6.months.ago).count}"
```

2. Verify affordability analysis:
```ruby
analyzer = AffordabilityAnalyzer.new(family, :house)
results = analyzer.analyze
puts "Analysis successful: #{results[:error].nil?}"
puts "Error message: #{results[:error]}" if results[:error]
```

## Expected Outcome
- No more ambiguous column errors
- Correct counting of transactions within the 6-month period
- Proper affordability analysis when sufficient transaction history exists

## Additional Notes
- This fix ensures proper SQL query generation when dealing with complex joins
- The solution maintains existing functionality while fixing the ambiguous column reference
- All date-related queries should explicitly reference the table to prevent similar issues 