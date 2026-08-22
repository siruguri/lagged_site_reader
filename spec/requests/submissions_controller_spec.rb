require "rails_helper"

RSpec.describe "SubmissionsController#toggle_status", type: :request do
  let(:account) { Account.create!(email: "writer@example.com", password: "password123456", confirmed_at: Time.current) }

  def json
    JSON.parse(response.body)
  end

  context "when signed in" do
    before { sign_in account }

    it "flips a draft submission to published" do
      submission = account.submissions.create!(title: "Draft Piece", content: "...", status: :draft)

      patch toggle_status_submission_path(submission), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json).to eq("id" => submission.id, "status" => "published")
      expect(submission.reload).to be_published
    end

    it "flips a published submission back to draft" do
      submission = account.submissions.create!(title: "Live Piece", content: "...", status: :published)

      patch toggle_status_submission_path(submission), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(json).to eq("id" => submission.id, "status" => "draft")
      expect(submission.reload).to be_draft
    end

    it "does not toggle another account's submission" do
      other_account = Account.create!(email: "someone-else@example.com", password: "password123456", confirmed_at: Time.current)
      other_submission = other_account.submissions.create!(title: "Not Yours", content: "...", status: :draft)

      patch toggle_status_submission_path(other_submission), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:not_found)
      expect(other_submission.reload).to be_draft
    end
  end

  context "when signed out" do
    it "does not toggle the submission" do
      submission = account.submissions.create!(title: "Draft Piece", content: "...", status: :draft)

      patch toggle_status_submission_path(submission), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
      expect(submission.reload).to be_draft
    end
  end
end
