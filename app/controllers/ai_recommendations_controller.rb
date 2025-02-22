class AiRecommendationsController < ApplicationController
  before_action :set_recommendation, only: [:accept, :dismiss]

  def accept
    @recommendation.accept!
    redirect_back(fallback_location: root_path, notice: "Recommendation accepted")
  end

  def dismiss
    @recommendation.dismiss!
    redirect_back(fallback_location: root_path, notice: "Recommendation dismissed")
  end

  def refresh
    begin
      # Clear existing pending recommendations
      Current.family.ai_recommendations.active.update_all(status: 'dismissed')
      
      # Generate new recommendations
      recommendations = AiRecommendation.generate_recommendations(Current.family)
      
      if recommendations.any?
        redirect_back(fallback_location: root_path, notice: "Generated #{recommendations.size} new recommendations")
      else
        redirect_back(fallback_location: root_path, alert: "No new recommendations available at this time. Please try again later.")
      end
    rescue => e
      Rails.logger.error "Error generating recommendations: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_back(fallback_location: root_path, alert: "Unable to generate recommendations at this time. Please try again later.")
    end
  end

  private

  def set_recommendation
    @recommendation = Current.family.ai_recommendations.find(params[:id])
  end
end 