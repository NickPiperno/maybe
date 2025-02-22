class AiRecommendation < ApplicationRecord
  include Monetizable
  
  belongs_to :family
  
  # Types of recommendations
  TYPES = %w[spending_analysis budget_adjustment savings_opportunity].freeze
  
  # Statuses for recommendations
  STATUSES = %w[pending accepted rejected dismissed].freeze
  
  validates :family, presence: true
  validates :recommendation_type, presence: true, inclusion: { in: TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :title, presence: true
  validates :description, presence: true
  validates :amount_cents, numericality: { only_integer: true, allow_nil: true }
  
  monetize :amount_cents, as: :amount, allow_nil: true
  
  scope :active, -> { where(status: 'pending') }
  scope :by_type, ->(type) { where(recommendation_type: type) }
  
  def self.generate_recommendations(family)
    analyzer = AiAnalyzer.new(family)
    analyzer.generate_recommendations
  end
  
  def accept!
    update!(status: 'accepted')
  end
  
  def reject!
    update!(status: 'rejected')
  end
  
  def dismiss!
    update!(status: 'dismissed')
  end
end 