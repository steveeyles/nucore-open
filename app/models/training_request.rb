class TrainingRequest < ActiveRecord::Base

  belongs_to :user
  belongs_to :product

  validates_presence_of :user, :product
  validates :user_id, uniqueness: { scope: :product_id }

  validates_with ProductRequiresApprovalValidator

  scope :from_product_user, -> (product_user) do
    where(user_id: product_user.user_id, product_id: product_user.product_id)
  end

  def self.submitted?(user, product)
    where(product_id: product.id, user_id: user.id).present?
  end

end
