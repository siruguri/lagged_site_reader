require "rails_helper"

RSpec.describe WritingController, type: :controller do
  describe "GET #prompt" do
    context "when a writing prompt exists for today" do
      it "returns the existing prompt" do
        prompt_text = "test prompt text"
        WritingPrompt.create!(prompt: prompt_text, prompt_on: Date.current)

        get :prompt

        expect(assigns(:answer)).to eq(prompt_text)
        expect(response).to be_successful
      end

      it "does not call OpenaiClient" do
        WritingPrompt.create!(prompt: "existing prompt", prompt_on: Date.current)

        expect_any_instance_of(OpenaiClient).not_to receive(:ask)

        get :prompt
      end
    end

    context "when no writing prompt exists for today" do
      it "creates a new writing prompt and returns the answer" do
        allow_any_instance_of(OpenaiClient).to receive(:ask).and_return("generated prompt")

        get :prompt

        expect(assigns(:answer)).to eq("generated prompt")
        expect(WritingPrompt.find_by(prompt_on: Date.current)).to be_present
        expect(WritingPrompt.find_by(prompt_on: Date.current).prompt).to eq("generated prompt")
      end

      it "calls OpenaiClient with correct parameters" do
        expect_any_instance_of(OpenaiClient).to receive(:ask).with(anything, temperature: 1.0).and_return("new prompt")

        get :prompt
      end

      it "includes a seed word in the prompt sent to OpenaiClient" do
        received_prompt = nil
        allow_any_instance_of(OpenaiClient).to receive(:ask) do |instance, prompt, **kwargs|
          received_prompt = prompt
          "generated"
        end

        get :prompt

        expect(received_prompt).to include("Seed word")
      end
    end

    context "when multiple requests are made on the same day" do
      it "returns the same prompt for all requests on the same day" do
        allow_any_instance_of(OpenaiClient).to receive(:ask).and_return("first prompt")

        get :prompt
        first_answer = assigns(:answer)

        allow_any_instance_of(OpenaiClient).to receive(:ask).and_return("second prompt")

        get :prompt
        second_answer = assigns(:answer)

        expect(first_answer).to eq(second_answer)
      end
    end

    it "renders the prompt template" do
      allow_any_instance_of(OpenaiClient).to receive(:ask).and_return("test answer")

      get :prompt

      expect(response).to render_template(:prompt)
    end
  end
end
