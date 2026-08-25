class PagesController < ApplicationController
  before_action :authenticate_account!, only: :profile

  def landing
  end

  def list
  end

  def profile
  end
end
