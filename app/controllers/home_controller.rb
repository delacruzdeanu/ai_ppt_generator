class HomeController < ApplicationController
  def index
    # Debug API key presence - will show in server logs
    Rails.logger.info("ANTHROPIC_API_KEY present: #{ENV['ANTHROPIC_API_KEY'].present?}")
  end
end
