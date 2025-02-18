require_relative '../services/spending_report_export'

class TransactionsController < ApplicationController
  include ScrollFocusable

  layout :with_sidebar

  before_action :store_params!, only: :index

  def index
    @q = search_params
    search_query = Current.family.transactions.search(@q).active

    set_focused_record(search_query, params[:focused_record_id], default_per_page: 50)

    @pagy, @transaction_entries = pagy(
      search_query.reverse_chronological.preload(
        :account,
        entryable: [
          :category, :merchant, :tags,
          :transfer_as_inflow,
          transfer_as_outflow: {
            inflow_transaction: { entry: :account },
            outflow_transaction: { entry: :account }
          }
        ]
      ),
      limit: params[:per_page].presence || default_params[:per_page],
      params: ->(params) { params.except(:focused_record_id) }
    )

    @transfers = @transaction_entries.map { |entry| entry.entryable.transfer_as_outflow }.compact
    @totals = search_query.stats(Current.family.currency)
  end

  def spending_reports
    @period = Period.new(params[:period])
    
    # Base query for expenses only
    expense_query = Current.family.entries
      .joins("LEFT JOIN account_transactions ON account_transactions.id = account_entries.entryable_id AND account_entries.entryable_type = 'Account::Transaction'")
      .joins("LEFT JOIN categories ON categories.id = account_transactions.category_id")
      .joins("LEFT JOIN transfers ON transfers.inflow_transaction_id = account_transactions.id OR transfers.outflow_transaction_id = account_transactions.id")
      .where(date: @period.date_range)
      .where("transfers.id IS NULL") # Exclude transfers
      .where("account_entries.amount > 0") # Only include outflows (expenses)
      .where(
        "categories.classification = 'expense' OR " \
        "(categories.id IS NULL AND account_entries.entryable_type = 'Account::Transaction')"
      )

    @totals = Current.family.entries
      .where(date: @period.date_range)
      .stats(Current.family.currency)
    @expense_count = expense_query.count

    respond_to do |format|
      format.html do
        # Get daily spending totals with caching
        @spending_series = Rails.cache.fetch(["spending_series", Current.family.id, @period.type, Current.family.entries.maximum(:updated_at)&.to_i]) do
          # Calculate cumulative spending
          daily_totals = expense_query
            .group("DATE(account_entries.date)")
            .select("DATE(account_entries.date) as date, SUM(account_entries.amount) as total")
            .order("date ASC") # Ensure chronological order for cumulative sum

          # Initialize all dates with zero
          all_dates = (@period.date_range.begin..@period.date_range.end).map { |date| [date, Money.new(0, Current.family.currency)] }.to_h
          
          # Calculate cumulative spending
          running_total = Money.new(0, Current.family.currency)
          daily_totals.each do |row|
            running_total += Money.new(row.total, Current.family.currency)
            all_dates[row.date] = running_total
          end

          # Ensure all dates after the last expense show the final total
          last_total = running_total
          all_dates.keys.sort.each do |date|
            if all_dates[date].zero?
              all_dates[date] = last_total
            else
              last_total = all_dates[date]
            end
          end
          
          TimeSeries.new(
            all_dates.map { |date, total| { date: date, value: total } },
            favorable_direction: "down"
          )
        end

        @transaction_entries = expense_query
          .order(date: :desc, created_at: :desc)
          .preload(entryable: [:category, :merchant, :tags])

        @pagy, @transaction_entries = pagy(@transaction_entries)
      end

      format.csv do
        export = SpendingReportExport.new(period: @period, family: Current.family)
        send_data export.to_csv,
          filename: "spending-report-#{@period.type}-#{Date.current}.csv",
          type: "text/csv"
      end

      format.pdf do
        export = SpendingReportExport.new(period: @period, family: Current.family)
        send_data export.to_pdf,
          filename: "spending-report-#{@period.type}-#{Date.current}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def clear_filter
    updated_params = {
      "q" => search_params,
      "page" => params[:page],
      "per_page" => params[:per_page]
    }

    q_params = updated_params["q"] || {}

    param_key = params[:param_key]
    param_value = params[:param_value]

    if q_params[param_key].is_a?(Array)
      q_params[param_key].delete(param_value)
      q_params.delete(param_key) if q_params[param_key].empty?
    else
      q_params.delete(param_key)
    end

    updated_params["q"] = q_params.presence
    Current.session.update!(prev_transaction_page_params: updated_params)

    redirect_to transactions_path(updated_params)
  end

  private
    def search_params
      cleaned_params = params.fetch(:q, {})
            .permit(
              :start_date, :end_date, :search, :amount,
              :amount_operator, accounts: [], account_ids: [],
              categories: [], merchants: [], types: [], tags: []
            )
            .to_h
            .compact_blank

      cleaned_params.delete(:amount_operator) unless cleaned_params[:amount].present?

      cleaned_params
    end

    def store_params!
      if should_restore_params?
        params_to_restore = {}

        params_to_restore[:q] = stored_params["q"].presence || default_params[:q]
        params_to_restore[:page] = stored_params["page"].presence || default_params[:page]
        params_to_restore[:per_page] = stored_params["per_page"].presence || default_params[:per_page]

        redirect_to transactions_path(params_to_restore)
      else
        Current.session.update!(
          prev_transaction_page_params: {
            q: search_params,
            page: params[:page],
            per_page: params[:per_page]
          }
        )
      end
    end

    def should_restore_params?
      request.query_parameters.blank? && (stored_params["q"].present? || stored_params["page"].present? || stored_params["per_page"].present?)
    end

    def stored_params
      Current.session.prev_transaction_page_params
    end

    def default_params
      {
        q: {},
        page: 1,
        per_page: 50
      }
    end
end
