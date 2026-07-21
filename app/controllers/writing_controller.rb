class WritingController < ApplicationController
  def prompt
    writing_prompt = WritingPrompt.find_by(prompt_on: Date.current)

    @answer = writing_prompt || get_prompt_from_llm
  end

  private
  def get_prompt_from_llm
    answer = OpenaiClient.new.ask(temperature: 1.0)
    WritingPrompt.create(prompt: answer, prompt_on: Date.current)
  end
end
