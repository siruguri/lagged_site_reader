class PagesController < ApplicationController
  def landing
    redirect_to submissions_path if account_signed_in?
  end

  def list
  end
end
