class SpendingReportExport
  def initialize(period:, family:)
    @period = period
    @family = family
    @currency = family.currency
  end

  def to_csv
    CSV.generate do |csv|
      # Header row
      csv << ["Spending Report", "", ""]
      csv << ["Period", @period.name, ""]
      csv << ["Currency", @currency, ""]
      csv << ["", "", ""]

      # Summary section
      totals = @family.entries.where(date: @period.date_range).stats(@currency)
      csv << ["Total Spending", totals.expense_total, ""]
      csv << ["Total Income", totals.income_total, ""]
      csv << ["Net Income", totals.income_total - totals.expense_total, ""]
      csv << ["", "", ""]

      # Top Categories section
      csv << ["Top Categories", "", ""]
      csv << ["Category", "Amount", "Percentage"]
      category_data = @family.expense_categories_with_totals_for_period(
        start_date: @period.date_range.begin,
        end_date: @period.date_range.end
      ).category_totals

      category_data.each do |ct|
        csv << [
          ct.category&.name || "Uncategorized",
          ct.amount_money.amount,
          ct.percentage
        ]
      end
      csv << ["", "", ""]

      # Daily spending section
      csv << ["Daily Spending", "", ""]
      csv << ["Date", "Amount", "Cumulative"]
      
      daily_totals = @family.entries
        .joins("LEFT JOIN account_transactions ON account_transactions.id = account_entries.entryable_id AND account_entries.entryable_type = 'Account::Transaction'")
        .joins("LEFT JOIN transfers ON transfers.inflow_transaction_id = account_transactions.id OR transfers.outflow_transaction_id = account_transactions.id")
        .where(date: @period.date_range)
        .where("transfers.id IS NULL")
        .where("account_entries.amount > 0")
        .group("DATE(account_entries.date)")
        .select("DATE(account_entries.date) as date, SUM(account_entries.amount) as total")
        .order("date ASC")

      cumulative = 0
      daily_totals.each do |row|
        cumulative += row.total
        csv << [
          row.date,
          row.total,
          cumulative
        ]
      end
    end
  end

  def to_pdf
    require "prawn"
    require "prawn/table"
    
    pdf = Prawn::Document.new
    pdf.font "Helvetica"

    # Title
    pdf.font_size(24) { pdf.text "Spending Report" }
    pdf.move_down 20

    # Period and Currency info
    pdf.text "Period: #{@period.name}"
    pdf.text "Currency: #{@currency}"
    pdf.move_down 20

    # Summary section
    totals = @family.entries.where(date: @period.date_range).stats(@currency)
    pdf.font_size(14) { pdf.text "Summary" }
    summary_data = [
      ["Total Spending", Money.new(totals.expense_total * 100, @currency).format],
      ["Total Income", Money.new(totals.income_total * 100, @currency).format],
      ["Net Income", Money.new((totals.income_total - totals.expense_total) * 100, @currency).format]
    ]
    pdf.table(summary_data, width: pdf.bounds.width) do |t|
      t.cells.borders = []
      t.cells.padding = [5, 10]
    end
    pdf.move_down 20

    # Top Categories section
    pdf.font_size(14) { pdf.text "Top Categories" }
    category_data = @family.expense_categories_with_totals_for_period(
      start_date: @period.date_range.begin,
      end_date: @period.date_range.end
    ).category_totals

    categories_table_data = [["Category", "Amount", "Percentage"]]
    category_data.each do |ct|
      categories_table_data << [
        ct.category&.name || "Uncategorized",
        ct.amount_money.format,
        "#{ct.percentage}%"
      ]
    end

    pdf.table(categories_table_data, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.cells.borders = [:bottom]
      t.cells.border_width = 0.5
      t.cells.padding = [5, 10]
    end
    pdf.move_down 20

    # Daily spending section
    pdf.font_size(14) { pdf.text "Daily Spending" }
    daily_totals = @family.entries
      .joins("LEFT JOIN account_transactions ON account_transactions.id = account_entries.entryable_id AND account_entries.entryable_type = 'Account::Transaction'")
      .joins("LEFT JOIN transfers ON transfers.inflow_transaction_id = account_transactions.id OR transfers.outflow_transaction_id = account_transactions.id")
      .where(date: @period.date_range)
      .where("transfers.id IS NULL")
      .where("account_entries.amount > 0")
      .group("DATE(account_entries.date)")
      .select("DATE(account_entries.date) as date, SUM(account_entries.amount) as total")
      .order("date ASC")

    daily_table_data = [["Date", "Amount", "Cumulative"]]
    cumulative = 0
    daily_totals.each do |row|
      cumulative += row.total
      daily_table_data << [
        row.date,
        Money.new(row.total * 100, @currency).format,
        Money.new(cumulative * 100, @currency).format
      ]
    end

    pdf.table(daily_table_data, width: pdf.bounds.width) do |t|
      t.row(0).font_style = :bold
      t.cells.borders = [:bottom]
      t.cells.border_width = 0.5
      t.cells.padding = [5, 10]
    end

    pdf.render
  end
end 