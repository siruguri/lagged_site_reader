require "rails_helper"

RSpec.describe "ProfilesController#show", type: :request do
  let(:account) { Account.create!(email: "no-profile@example.com", password: "password123456", confirmed_at: Time.current) }

  context "when the account has no profile" do
    before do
      account.profile.destroy
      sign_in account
    end

    it "loads the profile page and creates a profile" do
      expect(account.reload.profile).to be_nil

      get profile_path

      expect(response).to have_http_status(:ok)
      expect(account.reload.profile).to be_present
    end
  end
end
