# Configure Anthropic gem
Anthropic.configure do |config|
  # Try to get API key from environment variable
  api_key = ENV['ANTHROPIC_API_KEY']
  
  # If not found in ENV, try to read directly from .env file (fallback for development)
  if api_key.blank? && Rails.env.development?
    begin
      env_file = File.read(Rails.root.join('.env'))
      if env_file =~ /ANTHROPIC_API_KEY=([^\s]+)/
        api_key = $1.strip
      end
    rescue => e
      Rails.logger.error("Failed to read .env file for Anthropic config: #{e.message}")
    end
  end
  
  config.access_token = api_key
  config.log_errors = true
end
