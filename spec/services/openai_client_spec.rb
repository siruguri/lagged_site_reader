require "rails_helper"

RSpec.describe OpenaiClient do
  describe "initialization" do
    it "raises an error when API key is missing" do
      allow(Rails.application.credentials).to receive(:openai_api_key).and_return(nil)

      expect { described_class.new }.to raise_error(OpenaiClient::Error, /missing OpenAI API key/)
    end
  end

  describe "#ask" do
    subject(:client) { described_class.new }

    it "returns a string response" do
      response_body = {
        "choices" => [{ "message" => { "content" => "test answer" } }]
      }.to_json
      stub_http_request(body: response_body)

      result = client.ask("What is 2+2?")

      expect(result).to eq("test answer")
    end

    it "uses default temperature of 0.2" do
      request_body = nil
      allow(Net::HTTP::Post).to receive(:new).and_wrap_original do |method, *args|
        post = method.call(*args)
        allow(post).to receive(:body=) { |body| request_body = body }
        post
      end
      stub_http_request(body: '{"choices": [{"message": {"content": "answer"}}]}')

      client.ask("prompt")

      parsed = JSON.parse(request_body)
      expect(parsed["temperature"]).to eq(0.2)
    end

    it "accepts a custom temperature parameter" do
      request_body = nil
      allow(Net::HTTP::Post).to receive(:new).and_wrap_original do |method, *args|
        post = method.call(*args)
        allow(post).to receive(:body=) { |body| request_body = body }
        post
      end
      stub_http_request(body: '{"choices": [{"message": {"content": "answer"}}]}')

      client.ask("prompt", temperature: 1.0)

      parsed = JSON.parse(request_body)
      expect(parsed["temperature"]).to eq(1.0)
    end

    it "sets max_tokens to 150" do
      request_body = nil
      allow(Net::HTTP::Post).to receive(:new).and_wrap_original do |method, *args|
        post = method.call(*args)
        allow(post).to receive(:body=) { |body| request_body = body }
        post
      end
      stub_http_request(body: '{"choices": [{"message": {"content": "answer"}}]}')

      client.ask("prompt")

      parsed = JSON.parse(request_body)
      expect(parsed["max_tokens"]).to eq(150)
    end

    it "includes system and user messages" do
      request_body = nil
      allow(Net::HTTP::Post).to receive(:new).and_wrap_original do |method, *args|
        post = method.call(*args)
        allow(post).to receive(:body=) { |body| request_body = body }
        post
      end
      stub_http_request(body: '{"choices": [{"message": {"content": "answer"}}]}')

      client.ask("user prompt text")

      parsed = JSON.parse(request_body)
      messages = parsed["messages"]
      expect(messages[0]["role"]).to eq("system")
      expect(messages[1]["role"]).to eq("user")
      expect(messages[1]["content"]).to include("user prompt text")
    end

    it "strips whitespace from the response" do
      response_body = {
        "choices" => [{ "message" => { "content" => "  answer with spaces  \n" } }]
      }.to_json
      stub_http_request(body: response_body)

      result = client.ask("prompt")

      expect(result).to eq("answer with spaces")
    end

    it "raises an error when the API response is not successful" do
      http_response = instance_double(Net::HTTPClientError, body: '{"error":{"message":"Invalid"}}', code: "401")
      allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:new).and_return(http)
      allow(http).to receive(:use_ssl=)
      allow(http).to receive(:open_timeout=)
      allow(http).to receive(:read_timeout=)
      allow(http).to receive(:request).and_return(http_response)

      expect { client.ask("prompt") }.to raise_error(OpenaiClient::Error)
    end

    it "returns nil if response content is nil" do
      response_body = {
        "choices" => [{ "message" => { "content" => nil } }]
      }.to_json
      stub_http_request(body: response_body)

      result = client.ask("prompt")

      expect(result).to be_nil
    end
  end

  private

  def stub_http_request(body: '{"choices": [{"message": {"content": "mocked"}}]}')
    http_response = instance_double(Net::HTTPSuccess, body: body, code: "200")
    allow(http_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(http_response)
  end
end
