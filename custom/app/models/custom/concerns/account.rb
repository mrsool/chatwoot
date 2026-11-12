module Custom::Concerns::Account
  extend ActiveSupport::Concern

  included do
    has_many :away_reasons, dependent: :destroy_async
  end
end
