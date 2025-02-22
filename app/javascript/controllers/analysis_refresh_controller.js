import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.refreshContent()
  }

  async refreshContent() {
    const analysisId = this.element.dataset.analysisId
    
    try {
      const response = await fetch(`/affordability_analysis/${analysisId}/results`, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      if (!response.ok) throw new Error('Failed to fetch results')
      
      const html = await response.text()
      this.element.outerHTML = html
    } catch (error) {
      console.error('Error fetching analysis results:', error)
      this.element.innerHTML = `
        <div class="bg-red-50 rounded-xl p-6 text-center">
          <div class="flex flex-col items-center gap-3">
            <div class="space-y-1">
              <h3 class="font-medium text-red-700">Error Loading Results</h3>
              <p class="text-sm text-red-600">Please refresh the page to try again.</p>
            </div>
          </div>
        </div>
      `
    }
  }
} 