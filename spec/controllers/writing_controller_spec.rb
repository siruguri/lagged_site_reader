require "rails_helper"

RSpec.describe WritingController, type: :controller do
  describe "GET #prompt" do
    context "when a writing prompt exists for today" do
      it "returns the existing prompt" do
        prompt_text = "test prompt text"
        WritingPrompt.create!(prompt: prompt_text, prompt_on: Date.current)
        expect_any_instance_of(OpenaiClient).not_to receive(:ask)

        get :prompt

        expect(assigns(:answer).prompt).to eq(prompt_text)
        expect(response).to be_successful
      end
    end

    context "when no writing prompt exists for today" do
      it "creates a new writing prompt and returns the answer" do
        allow_any_instance_of(OpenaiClient).to receive(:ask).and_return("generated prompt")

        get :prompt

        expect(assigns(:answer).prompt).to eq("generated prompt")
        saved_prompt = WritingPrompt.find_by(prompt_on: Date.current)
        expect(saved_prompt&.prompt).to eq("generated prompt")
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
