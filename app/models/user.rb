class User < ApplicationRecord
  include SoftDeletable

  has_secure_password

  has_many :contexts, dependent: :destroy
  has_many :lists, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :audit_logs, dependent: :nullify
  has_many :chat_messages, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    uniqueness: { case_sensitive: false }
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_save { self.email = email.downcase }

  def active?
    !discarded?
  end
end
