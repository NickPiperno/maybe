class AffordabilityAnalysisJob < ApplicationJob
  queue_as :default

  MAX_ERROR_LENGTH = 1000 # Maximum length for error messages

  def perform(analysis_status_id)
    Rails.logger.info "Starting AffordabilityAnalysisJob for status ID: #{analysis_status_id}"
    
    analysis_status = AnalysisStatus.includes(
      family: [
        :accounts,
        :entries,
        :categories,
        :merchants,
        :budgets,
        :budget_categories
      ]
    ).find(analysis_status_id)
    
    Rails.logger.tagged("AffordabilityAnalysis##{analysis_status_id}") do
      Rails.logger.info "Found analysis_status with goal_type: #{analysis_status.goal_type}"
      Rails.logger.info "Current status: #{analysis_status.status}"
      Rails.logger.info "Current step: #{analysis_status.current_step}"
      
      # Update status to processing
      analysis_status.update!(status: :processing)
      Rails.logger.info "Updated status to processing"
      
      # Broadcast initial processing state
      broadcast_progress(analysis_status, "Analyzing your financial data...")
      Rails.logger.info "Broadcasted initial progress"
      
      # Run the analysis
      analyzer = AffordabilityAnalyzer.new(analysis_status.family, analysis_status.goal_type)
      Rails.logger.info "Created analyzer instance"
      
      # Simulate steps for better UX
      broadcast_progress(analysis_status, "Calculating financial metrics...")
      sleep(1) # Small delay for UX
      
      broadcast_progress(analysis_status, "Generating AI recommendations...")
      
      # Add detailed logging around the analyze call
      Rails.logger.info "Starting analyze call..."
      begin
        Rails.logger.info "Calling analyzer.analyze..."
        results = analyzer.analyze
        Rails.logger.info "Analyze call completed successfully"
        
        # Log the size of the results
        results_json = results.to_json
        Rails.logger.info "Results size: #{results_json.bytesize} bytes"
        Rails.logger.debug "Raw results: #{results.inspect}"
        
        if results.nil?
          Rails.logger.error "Results were nil!"
          raise "Analyzer returned nil results"
        end
        
        if !results.is_a?(Hash)
          Rails.logger.error "Results were not a hash! Got: #{results.class}"
          raise "Analyzer returned non-hash results: #{results.class}"
        end

        # Check if the results contain an error
        if results[:error].present?
          Rails.logger.error "Analysis returned an error: #{results[:error]} - #{results[:message]}"
          update_error_status(analysis_status, results[:error], results[:message])
          broadcast_error(analysis_status)
          return
        end
        
        # Only save and broadcast results if they are valid (no error)
        Rails.logger.info "Updating analysis_status with results..."
        Rails.logger.debug "Results structure before save: #{results.keys}"
        
        # Ensure all required keys are present based on goal type
        valid_structure = case analysis_status.goal_type.to_sym
        when :house
          results[:financial_health].present? && results[:recommended_scenario].present?
        when :vacation
          results[:recommended_budget].present? && results[:vacation_suggestions].present?
        end

        unless valid_structure
          raise "Invalid results structure: missing required keys for #{analysis_status.goal_type} analysis"
        end
        
        # Log size of each major section
        results.each do |key, value|
          section_size = value.to_json.bytesize
          Rails.logger.info "Size of #{key}: #{section_size} bytes"
        end
        
        begin
          analysis_status.update!(
            status: :completed,
            results: results
          )
          Rails.logger.info "Updated analysis_status successfully"
          Rails.logger.debug "Saved results structure: #{analysis_status.reload.results.keys}"
        rescue ActiveRecord::StatementInvalid => e
          if e.message.include?("payload string too long")
            Rails.logger.error "Results payload too large: #{results_json.bytesize} bytes"
            raise "Results exceeded maximum allowed size. Try reducing the number of scenarios or the amount of detail in the analysis."
          else
            raise e
          end
        end
        
        # Broadcast completion with results
        broadcast_results(analysis_status)
        Rails.logger.info "Broadcasted final results"
      rescue => e
        Rails.logger.error "Error in analysis job: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        
        # Update status to failed and broadcast error
        update_error_status(analysis_status, "analysis_error", e.message)
        broadcast_error(analysis_status)
      end
    end
  end

  private

  def update_error_status(analysis_status, error_type, message)
    # Truncate error message if it's too long
    truncated_message = if message.include?("payload string too long")
      "The analysis generated too much data. Please try again with fewer scenarios."
    else
      message.to_s.truncate(MAX_ERROR_LENGTH)
    end

    analysis_status.update!(
      status: :failed,
      results: {
        error: error_type,
        message: truncated_message
      }
    )
  end

  def broadcast_progress(analysis_status, message)
    Rails.logger.info "Broadcasting progress: #{message}"
    analysis_status.update!(current_step: message)
    Turbo::StreamsChannel.broadcast_replace_to(
      analysis_status.family,
      target: "analysis_status",
      partial: "shared/analysis_status",
      locals: { message: message }
    )
  end

  def broadcast_results(analysis_status)
    Rails.logger.info "Broadcasting results..."
    
    # Instead of sending full results, just send a minimal payload to trigger refresh
    Turbo::StreamsChannel.broadcast_replace_to(
      analysis_status.family,
      target: "analysis_content",
      html: "<div data-controller='analysis-refresh' data-analysis-id='#{analysis_status.id}'></div>"
    )
    Rails.logger.info "Results broadcast completed"
  end

  def broadcast_error(analysis_status)
    Rails.logger.info "Broadcasting error: #{analysis_status.results[:message]}"
    
    # Keep error broadcasts minimal as well
    Turbo::StreamsChannel.broadcast_replace_to(
      analysis_status.family,
      target: "analysis_content",
      html: render_error_message(analysis_status.results[:message])
    )
  end

  def render_error_message(message)
    <<~HTML
      <div class="bg-red-50 rounded-xl p-6 text-center">
        <div class="flex flex-col items-center gap-3">
          <svg class="w-8 h-8 text-red-500" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
          <div class="space-y-1">
            <h3 class="font-medium text-red-700">Analysis Failed</h3>
            <p class="text-sm text-red-600">#{message}</p>
          </div>
          <button onclick="window.location.reload()" class="btn btn--secondary mt-4">
            <svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            <span>Try Again</span>
          </button>
        </div>
      </div>
    HTML
  end
end 