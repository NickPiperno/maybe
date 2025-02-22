class AnalysisStatus < ApplicationRecord
  belongs_to :family
  
  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }, _prefix: :status
  enum goal_type: { house: 0, vacation: 1 }
  
  validates :goal_type, presence: true
  validates :status, presence: true

  def processing?
    status_pending? || status_processing?
  end

  def failed?
    status_failed?
  end

  def completed?
    status_completed?
  end

  def results
    return nil unless super
    @decompressed_results ||= begin
      json_string = if super.start_with?('x\x9C')
        Zlib::Inflate.inflate(Base64.decode64(super))
      else
        super
      end
      JSON.parse(json_string, symbolize_names: true)
    rescue => e
      nil
    end
  end

  def results=(value)
    @decompressed_results = nil
    return super(nil) if value.nil?

    json_string = value.is_a?(String) ? value : value.to_json
    if json_string.bytesize > 7000 # Compress if larger than ~7KB
      compressed = Zlib::Deflate.deflate(json_string)
      super(Base64.encode64(compressed))
    else
      super(json_string)
    end
  end
end 