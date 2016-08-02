module Api

  module Acgt

    class OrderDetailsController < ApplicationController

      respond_to :json

      http_basic_authenticate_with name: "acgt", password: "TODO"

      before_action :load_order_details, only: [:index]
      before_action :load_order_detail, only: [:show]

      def index
        render json: order_details_as_array
      end

      def show
        render json: order_detail_as_hash
      end

      private

      def facility
        @facility ||= Facility.find_by(url_name: "zed") # TODO: temporarily restrict to Zed Test Facility
      end

      def order_detail_as_hash
        ::Acgt::OrderDetailSerializer.new(@order_detail).to_h(with_samples: true)
      end

      def order_details_as_array
        @order_details.map do |order_detail|
          ::Acgt::OrderDetailSerializer.new(order_detail).to_h(with_samples: false)
        end
      end

      def load_order_detail
        order_id, order_detail_id = params[:id].split(/\-/, 2)
        @order_detail = Order.purchased.find(order_id).order_details.find(order_detail_id)
      end

      def load_order_details
        @order_details =
          facility
          .order_details # TODO: restrict to configured product_ids
          .joins(:order)
          .where("orders.ordered_at >= ?", date_from_param.beginning_of_day)
          .where("orders.ordered_at <= ?", date_from_param.end_of_day)
      end

      def date_from_param
        params[:date].to_date
      end

    end

  end

end
