class PresentationsController < ApplicationController
  def create
    # Get parameters from the form
    title = params[:title]
    content = params[:content]
    style = params[:style]
    slides_count = params[:slides].to_i

    begin
      # Validate input parameters
      return render json: { error: "Title is required" }, status: :unprocessable_entity if title.blank?
      return render json: { error: "Content is required" }, status: :unprocessable_entity if content.blank?
      return render json: { error: "Style is required" }, status: :unprocessable_entity if style.blank?
      return render json: { error: "Number of slides must be between 1 and 50" }, status: :unprocessable_entity if slides_count < 1 || slides_count > 50

      # Generate content using Anthropic
      Rails.logger.info("Starting content generation for presentation: #{title}")
      slide_content = generate_slide_content(title, content, style, slides_count)
      Rails.logger.info("Content generated successfully, slides: #{slide_content.length}")

      # Create the PowerPoint using python-pptx
      Rails.logger.info("Starting PowerPoint generation")
      pptx_file = generate_pptx(title, slide_content, style)
      Rails.logger.info("PowerPoint generated successfully")

      # Return the file for download
      send_data pptx_file,
                type: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                disposition: "attachment",
                filename: "#{title.presence || 'presentation'}.pptx"
    rescue => e
      Rails.logger.error("Presentation generation failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def generate_slide_content(title, content, style, slides_count)
    # Get the API key from environment variables only (more secure)
    api_key = ENV["ANTHROPIC_API_KEY"]

    if api_key.blank?
      raise "Anthropic API key is missing. Please set the ANTHROPIC_API_KEY environment variable"
    end

    # Initialize Anthropic client
    client = Anthropic::Client.new(
      access_token: api_key,
      log_errors: true
    )

    # Create a detailed prompt for Anthropic
    prompt = <<~PROMPT
      Create a professional presentation titled "#{title}".
      Style: #{style}
      Number of slides: #{slides_count}

      Content details: #{content}

      Format the output as a JSON array of slide objects with:
      1. "title" - The title of the slide (this should be a short, descriptive heading)
      2. "content" - IMPORTANT: This MUST be an array of strings containing substantial bullet points or paragraphs. Each slide MUST have at least 3-5 bullet points in the content array. Never leave this empty.
      3. "notes" - Optional presenter notes that won't appear on the slide itself

      Each slide should be focused and impactful.
      The response must be in valid JSON format with a "slides" array.

      Example of the expected format:
      {
        "slides": [
          {
            "title": "Introduction",
            "content": [
              "First key point about the topic with sufficient detail",
              "Second important aspect to consider with supporting information",
              "Third relevant detail with explanation",
              "Fourth point elaborating on the topic"
            ],
            "notes": "Spend about 2 minutes on this slide"
          }
        ]
      }

      MAKE SURE each slide has a properly populated content array with multiple substantial bullet points.
    PROMPT

    parameters = {
      model: "claude-3-opus-20240229",
      max_tokens: 4000,
      messages: [
        { role: "user", content: prompt }
      ],
      system: "You are a professional presentation designer who creates clear, structured slides. Always respond with valid JSON.",
      temperature: 0.7
    }

    Rails.logger.info("Sending request to Anthropic API with parameters: #{parameters.except(:messages).inspect}")

    # Call Anthropic API with proper error handling
    begin
      response = client.messages(parameters: parameters)

      # Extract the response text - simplified approach
      response_text = ""

      if response.is_a?(Hash) && response["content"]
        response_content = response["content"]
        if response_content.is_a?(Array)
          response_text = response_content
            .select { |block| block["type"] == "text" }
            .map { |block| block["text"] }
            .join("")
        end
      elsif response.respond_to?(:to_h)
        response_hash = response.to_h
        if response_hash["content"]
          content_blocks = response_hash["content"]
          if content_blocks.is_a?(Array)
            response_text = content_blocks
              .select { |block| block["type"] == "text" }
              .map { |block| block["text"] }
              .join("")
          end
        end
      end

      Rails.logger.info("Response text extracted, length: #{response_text.to_s.length}")

      # Parse and return the slide content
      begin
        # Clean response text to extract only valid JSON
        cleaned_json = extract_json_from_text(response_text)

        Rails.logger.info("Cleaned JSON text, length: #{cleaned_json.length}")

        parsed_response = JSON.parse(cleaned_json)

        if !parsed_response["slides"] || parsed_response["slides"].empty?
          Rails.logger.error("Invalid API response: missing or empty 'slides' array")
          raise "API returned invalid slide content. Please try again."
        end

        parsed_response["slides"]
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse JSON response: #{e.message}")
        Rails.logger.error("Raw response excerpt: #{response_text.to_s[0..200]}...")
        raise "Failed to parse AI response. Please try again."
      end
    rescue Faraday::Error => e
      Rails.logger.error("API request failed: #{e.class} - #{e.message}")
      if e.response
        Rails.logger.error("Status: #{e.response[:status]}")
        Rails.logger.error("Headers: #{e.response[:headers]}")
        Rails.logger.error("Body: #{e.response[:body]}")
      end
      raise "API request failed: #{e.message}"
    rescue => e
      Rails.logger.error("Anthropic API error: #{e.class} - #{e.message}")
      raise "Failed to generate content: #{e.message}"
    end
  end

  # Enhanced helper method to extract valid JSON from text
  def extract_json_from_text(text)
    # Find the first occurrence of '{' which should be the start of the JSON
    json_start = text.index("{")

    # If there's no JSON starting character, return the original text
    unless json_start
      Rails.logger.warn("No JSON object found in response")
      return text
    end

    # Extract from the starting brace to the end
    json_text = text[json_start..-1]

    # Attempt to balance braces to handle incomplete JSON
    open_braces = 0
    close_braces = 0

    json_text.each_char do |char|
      open_braces += 1 if char == "{"
      close_braces += 1 if char == "}"

      # Once we have matching braces, we likely have complete JSON
      break if open_braces > 0 && open_braces == close_braces
    end

    Rails.logger.info("JSON appears to start at position #{json_start}")

    # Return the extracted JSON portion
    json_text
  end

  def generate_pptx(title, slides, style)
    # This would typically be a call to a Python service
    # For now, we'll use a temporary file and shell out to Python
    require "tempfile"
    require "shellwords"
    require "open3"
    require "timeout"

    temp_json = nil
    temp_pptx = nil

    begin
      # Log the slide content to help with debugging
      if slides.first
        Rails.logger.info("Slide content structure: #{slides.first.keys.join(', ')}")

        # Ensure all slides have content and it's properly formatted
        slides.each_with_index do |slide, index|
          # Check if content exists and is an array
          if !slide["content"] || !slide["content"].is_a?(Array) || slide["content"].empty?
            Rails.logger.warn("Slide #{index + 1} has invalid or empty content: #{slide["content"].inspect}")
            # Fix it by providing a generic content if missing
            slide["content"] = [ "Point 1 about #{slide["title"]}", "Point 2 about #{slide["title"]}", "Point 3 about #{slide["title"]}" ]
            Rails.logger.info("Added default content to slide #{index + 1}")
          else
            Rails.logger.info("Slide #{index + 1} content: #{slide["content"].length} items")
          end
        end
      end

      # Create a temporary JSON file with slide content
      temp_json = Tempfile.new([ "slides", ".json" ])
      temp_json.write(slides.to_json)
      temp_json.close

      # Create a temporary PPTX file for output
      temp_pptx = Tempfile.new([ "presentation", ".pptx" ])
      temp_pptx.close

      # Path to the Python virtual environment
      venv_python = Rails.root.join("venv", "bin", "python")

      # Verify python environment exists
      unless File.exist?(venv_python)
        raise "Python virtual environment not found at #{venv_python}. Please run: python3 -m venv venv && source venv/bin/activate && pip install python-pptx"
      end

      # Run Python script with proper error handling
      python_script_path = Rails.root.join("lib", "python", "generate_pptx.py")

      unless File.exist?(python_script_path)
        raise "Python script not found at #{python_script_path}"
      end

      # Build command with properly escaped arguments to prevent command injection
      cmd = [
        venv_python.to_s,
        python_script_path.to_s,
        "--title", title.to_s,
        "--style", style.to_s,
        "--input", temp_json.path,
        "--output", temp_pptx.path
      ]

      Rails.logger.info("Executing command: #{cmd.join(' ')}")

      # Add timeout to prevent hanging
      output = nil
      status = nil

      Timeout.timeout(60) do  # 60 second timeout
        output, status = Open3.capture2e(*cmd)
      end

      Rails.logger.info("Command output: #{output}")

      unless status.success?
        raise "Python script failed: #{output}"
      end

      # Check if file was created
      unless File.exist?(temp_pptx.path) && File.size?(temp_pptx.path).to_i > 0
        raise "PPTX file was not generated properly at #{temp_pptx.path}"
      end

      # Read the generated file
      pptx_data = File.read(temp_pptx.path)

      # Return the binary data
      pptx_data

    rescue Timeout::Error
      Rails.logger.error("Python script execution timed out after 60 seconds")
      raise "Presentation generation timed out. Please try again with simpler content."
    rescue => e
      Rails.logger.error("PPTX generation error: #{e.message}")
      raise "Failed to generate presentation: #{e.message}"
    ensure
      # Clean up temporary files
      temp_json.unlink if temp_json && File.exist?(temp_json.path)
      temp_pptx.unlink if temp_pptx && File.exist?(temp_pptx.path)
    end
  end
end
