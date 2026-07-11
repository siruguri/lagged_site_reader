class WritingController < ApplicationController
  def prompt
    @answer = OpenaiClient.new.ask('Produce a short English phrase that isn\'t a sentence but that expresses some coherent idea or concept; something like a subordinate clause, or part of an idiom')
  end
end
