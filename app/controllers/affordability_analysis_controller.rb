class AffordabilityAnalysisController < ApplicationController
  layout "modal"

  def analyze
    Rails.logger.info "Starting affordability analysis for goal_type: #{goal_type}"
    
    @analysis = nil  # Initialize @analysis to nil for initial render
    @analysis_status = Current.family.analysis_statuses.create!(
      goal_type: goal_type,
      status: :pending,
      current_step: "Starting analysis..."
    )
    Rails.logger.info "Created analysis_status with ID: #{@analysis_status.id}"
    
    # Start background job
    job = AffordabilityAnalysisJob.perform_later(@analysis_status.id)
    Rails.logger.info "Enqueued AffordabilityAnalysisJob with job_id: #{job.job_id}"
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def results
    @analysis_status = Current.family.analysis_statuses.find(params[:id])
    
    render partial: "affordability_analysis/results",
           locals: {
             analysis: @analysis_status.results,
             goal_type: @analysis_status.goal_type,
             analysis_status: @analysis_status
           }
  end

  private

  def goal_type
    params[:goal_type]&.to_sym || :house
  end
end 