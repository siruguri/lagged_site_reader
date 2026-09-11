class ProfilesController < ApplicationController
  before_action :authenticate_account!
  before_action :set_profile

  def show
  end

  def update
    @profile.update(profile_params)
  end

  def update_avatar
    @profile.avatar.attach(params.require(:avatar))
    render json: { avatar_url: url_for(@profile.avatar) }
  end

  private

  def set_profile
    @profile = current_account.profile || current_account.create_profile!
  end

  def profile_params
    params.require(:profile).permit(:name, :bio)
  end
end
