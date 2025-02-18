class Period
  attr_reader :type

  def initialize(type = "last_30_days")
    @type = type.to_s
  end

  def self.last_30_days
    new("last_30_days")
  end

  def self.from_param(param)
    new(param.presence || "last_30_days")
  end

  def date_range
    case type
    when "last_30_days"
      30.days.ago.to_date..Date.current
    when "last_90_days"
      90.days.ago.to_date..Date.current
    when "last_12_months"
      12.months.ago.to_date..Date.current
    when "year_to_date"
      Date.current.beginning_of_year..Date.current
    else
      30.days.ago.to_date..Date.current
    end
  end

  def name
    case type
    when "last_30_days"
      "Last 30 days"
    when "last_90_days"
      "Last 90 days"
    when "last_12_months"
      "Last 12 months"
    when "year_to_date"
      "Year to date"
    else
      "Last 30 days"
    end
  end

  def last_30_days?
    type == "last_30_days"
  end

  def last_90_days?
    type == "last_90_days"
  end

  def last_12_months?
    type == "last_12_months"
  end

  def year_to_date?
    type == "year_to_date"
  end

  def extend_backward(duration)
    Period.new(name: name + "_extended", date_range: (date_range.first - duration)..date_range.last)
  end

  BUILTIN = [
    new(name: "all", date_range: nil..Date.current),
    new(name: "current_week", date_range: Date.current.beginning_of_week..Date.current),
    new(name: "last_7_days", date_range: 7.days.ago.to_date..Date.current),
    new(name: "current_month", date_range: Date.current.beginning_of_month..Date.current),
    new(name: "current_quarter", date_range: Date.current.beginning_of_quarter..Date.current),
    new(name: "current_year", date_range: Date.current.beginning_of_year..Date.current),
    new(name: "last_365_days", date_range: 365.days.ago.to_date..Date.current)
  ]

  INDEX = BUILTIN.index_by(&:name)

  BUILTIN.each do |period|
    define_singleton_method(period.name) do
      period
    end
  end
end
