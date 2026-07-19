class Submission < ApplicationRecord
  belongs_to :account

  enum :status, { draft: 0, published: 1 }
  enum :visibility, { closed: 0, open: 1 }

  validates :title, :content, presence: true
end
