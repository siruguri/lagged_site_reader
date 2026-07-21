class WritingController < ApplicationController
  SEED_WORDS = %w[lantern harbor granite whisper falcon orchard tundra velvet ember thicket].freeze

  def prompt
    writing_prompt = WritingPrompt.find_by(prompt_on: Date.current)

    @answer =
      if writing_prompt
        writing_prompt.prompt
    else
      seed_word = SEED_WORDS.sample
      prompt = <<~PROMPT.squish
        Produce a short English phrase that isn't a sentence but that expresses
        some coherent idea or concept; something like a subordinate clause, or
        part of an idiom. Seed word (do not use it directly, just let it loosely
        inspire the theme): #{seed_word}.
      PROMPT

      answer = OpenaiClient.new.ask(prompt, temperature: 1.0)
      WritingPrompt.create(prompt: answer, prompt_on: Date.current)

      answer
    end
  end
end
