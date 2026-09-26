# frozen_string_literal: true

require "net/http"

# Thin client for short question/answer calls to the OpenAI Chat Completions
# API. Answers are capped well under 500 characters via max_tokens plus an
# explicit system instruction, since token counts don't map 1:1 to characters.
class OpenaiClient
  class Error < StandardError; end

  PHRASE_FORMS = [
    "a metaphor",
    "a fragment of dialogue",
    "part of an idiom",
    "a sensory description",
    "a contradiction",
    "a proverb-like phrase",
    "a subordinate clause",
    "an image"
  ].freeze

  API_URL = URI("https://api.openai.com/v1/chat/completions")
  SYSTEM_PROMPT = "Answer as briefly as possible. Avoid all conversational courtesies."

  def initialize(api_key: Rails.application.credentials.openai_api_key, model: "gpt-4.1-mini")
    raise Error, "missing OpenAI API key" if api_key.blank?

    @api_key = api_key
    @model = model
  end

  def ask(temperature: 0.2, prompt: writing_prompt_query)
    response = post(
      model: @model,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: prompt }
      ],
      max_tokens: 150,
      temperature: temperature
    )

    response.dig("choices", 0, "message", "content")&.strip
  end

  private

  def writing_prompt_query
    seed_word = SeedPrompts::SEED_WORDS.sample
    phrase_form = PHRASE_FORMS.sample

    <<~PROMPT.squish
      Produce a short English phrase that isn't a sentence but that expresses
      some coherent idea or concept, in the form of #{phrase_form}. To help
      randomize the output, this prompt contains a seed word - it's imperative
      that this word, and any direct synonym or paraphrase of it, not appear
      in the phrase; it's only there to loosely inspire the theme in a way
      that shouldn't be obvious from the result: #{seed_word}.
    PROMPT
  end

  def post(body)
    request = Net::HTTP::Post.new(API_URL)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    http = Net::HTTP.new(API_URL.host, API_URL.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 20

    response = http.request(request)
    parsed = JSON.parse(response.body)
    raise Error, parsed.dig("error", "message") || "OpenAI request failed (#{response.code})" unless response.is_a?(Net::HTTPSuccess)

    parsed
  end
end
