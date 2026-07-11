class WritingController < ApplicationController
  SEED_WORDS = %w[lantern harbor granite whisper falcon orchard tundra velvet ember thicket].freeze

  def prompt
    seed_word = SEED_WORDS.sample
    prompt = <<~PROMPT.squish
      Produce a short English phrase that isn't a sentence but that expresses
      some coherent idea or concept; something like a subordinate clause, or
      part of an idiom. Seed word (do not use it directly, just let it loosely
      inspire the theme): #{seed_word}.
    PROMPT

    @answer = OpenaiClient.new.ask(prompt, temperature: 1.0)
  end
end
