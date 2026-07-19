class SubmissionsController < ApplicationController
  before_action :authenticate_account!

  def show
    @submission = Submission.find params[:id]
  end

  def index
    @submissions = current_account.submissions.order(created_at: :desc)
  end

  def new
    @submission = Submission.new
  end

  def create
    @submission = current_account.submissions.build(submission_params)
    if @submission.save
      redirect_to root_path, notice: 'Submission created successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def submission_params
    params.require(:submission).permit(:title, :content, :status, :visibility)
  end
end
