class ProfilesController < ApplicationController
  before_action :authenticate_account!
  before_action :set_profile, only: [:show, :update]

  def show
  end

  def update
    @profile.update(profile_params)
  end

  def update_avatar
    current_account.profile.avatar.attach(params.require(:avatar))
    render json: { avatar_url: url_for(current_account.profile.avatar) }
  end

  private

  def set_profile
    @profile = current_account.profile
  end

  def profile_params
    params.require(:profile).permit(:name, :bio)
  end
end
