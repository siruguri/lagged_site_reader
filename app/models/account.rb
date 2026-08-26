class Account < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable

  has_many :submissions, dependent: :destroy
  has_one :profile, dependent: :destroy

  after_create :create_profile!
end
