module SangerSequencing

  class Submission < ActiveRecord::Base

    self.table_name = "sanger_sequencing_submissions"

    include ActiveModel::ForbiddenAttributesProtection

    validates :savable_samples, length: { minimum: 1 }, on: :update

    belongs_to :order_detail, class_name: "::OrderDetail"
    belongs_to :batch, class_name: "SangerSequencing::Batch", inverse_of: :submissions
    has_one :order, through: :order_detail
    has_one :user, through: :order
    has_one :facility, through: :order
    has_many :samples

    accepts_nested_attributes_for :samples, allow_destroy: true

    delegate :order_id, :user, :order_status, :note, :product, to: :order_detail
    delegate :purchased?, :ordered_at, to: :order
    alias purchased_at ordered_at

    scope :purchased, -> { joins(:order).merge(Order.purchased.order(ordered_at: :desc)) }
    scope :ready_for_batch, -> { purchased.merge(OrderDetail.new_or_inprocess).where(batch_id: nil) }
    scope :for_facility, -> (facility) { where(orders: { facility_id: facility.id }) }

    def self.for_product_group(product_group)
      if product_group
        where(order_details: { product_id: ProductGroup.where(group: product_group).pluck(:product_id) })
      else
        where.not(order_details: { product_id: ProductGroup.pluck(:product_id) })
      end
    end

    def create_samples!(quantity)
      quantity = quantity.to_i
      raise ArgumentError, "quantity must be positive" if quantity <= 0
      transaction do
        Array.new(quantity) { samples.create! }
      end
    end

    def has_results_files?
      order_detail.sample_results_files.present?
    end

    # You cannot edit the quantity of a bundled product, so If the order is
    # placed via a bundle, then we should not be able to edit the quantity.
    def quantity_editable?
      order_detail.bundle.blank?
    end

    private

    def savable_samples
      samples.reject(&:marked_for_destruction?)
    end

  end

end
