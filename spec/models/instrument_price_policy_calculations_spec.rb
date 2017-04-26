require "rails_helper"

RSpec.describe InstrumentPricePolicyCalculations do

  subject(:policy) { build :instrument_price_policy, options }
  let(:options) { {} }

  let(:now) { Time.zone.now }
  let(:start_at) { Time.zone.parse "2013-12-13 09:00" }
  let(:end_at) { Time.zone.parse "2013-12-14 12:00" }
  let(:duration) { (end_at - start_at) / 60 }
  let(:reservation) { create :setup_reservation, product: policy.product }

  it 'uses the given order detail to #calculate_cost_and_subsidy' do
    fake_order_detail = double "OrderDetail", reservation: double("Reservation")
    expect(policy).to receive(:calculate_cost_and_subsidy).with fake_order_detail.reservation
    policy.calculate_cost_and_subsidy_from_order_detail fake_order_detail
  end


  # it "calculates cost based on the given duration and discount" do
  #   policy.usage_rate = 5
  #   expect(policy.calculate_cost(120, 0.15).round 2).to eq 1.5
  # end

  # it "calculates subsidy based on the given duration and discount" do
  #   policy.usage_subsidy = 5
  #   expect(policy.calculate_subsidy(120, 0.15).round 2).to eq 1.5
  # end

  describe "estimating cost and subsidy from an order detail" do
    it 'uses the given order detail to #estimate_cost_and_subsidy' do
      fake_reservation = double "Reservation", reserve_start_at: now, reserve_end_at: now + 1.hour
      fake_order_detail = double "OrderDetail", reservation: fake_reservation
      expect(policy).to receive(:estimate_cost_and_subsidy).with fake_reservation.reserve_start_at, fake_reservation.reserve_end_at
      policy.estimate_cost_and_subsidy_from_order_detail fake_order_detail
    end

    it "returns nil if the given order detail does not have a reservation" do
      fake_order_detail = double "OrderDetail", reservation: nil
      expect(policy.estimate_cost_and_subsidy_from_order_detail fake_order_detail).to be_nil
    end
  end

  describe "estimating cost and subsidy" do
    let(:costs) { policy.estimate_cost_and_subsidy start_at, end_at }

    it "returns nil if purchase is restricted" do
      allow(policy).to receive(:restrict_purchase?).and_return true
      expect(costs).to be_nil
    end

    it "returns nil if purchase if end_at is before start_at" do
      expect(policy.estimate_cost_and_subsidy(end_at, start_at)).to be_nil
    end

    it "returns nil if purchase if end_at equals start_at" do
      expect(policy.estimate_cost_and_subsidy(start_at, start_at)).to be_nil
    end

    describe "no usage rate or minimum cost" do
      let(:options) { { usage_rate: 0, usage_subsidy: 0, minimum_cost: 0 } }

      it "estimates zero cost" do
        expect(costs[:cost]).to eq 0
        expect(costs[:subsidy]).to eq 0
      end
    end

    describe "no usage rate, but there is a minumum cost" do
      let(:options) { { usage_rate: 0, usage_subsidy: 0, minimum_cost: 10 } }
      it "estimates the minimum cost" do
        expect(costs[:cost]).to eq 10
        expect(costs[:subsidy]).to eq 0
      end
    end

    # it "gives the calculated cost and subsidy" do
      # discount = 0.999
      # expect(policy).to receive(:calculate_discount).with(start_at, end_at).and_return discount
      # cost = 5.00
      # expect(policy).to receive(:calculate_cost).with(duration, discount).and_return cost
      # subsidy = 1.00
      # expect(policy).to receive(:calculate_subsidy).with(duration, discount).and_return subsidy
      # results = policy.estimate_cost_and_subsidy start_at, end_at
      # expect(results[:cost]).to eq cost
      # expect(results[:subsidy]).to eq subsidy
    # end

    # xit "gives the minimum cost with subsidies" do
    #   discount = 0
    #   duration = 61.0
    #   end_at = start_at + duration.minutes
    #   policy.minimum_cost = 60.0
    #   expect(policy).to receive(:calculate_discount).with(start_at, end_at).and_return discount
    #   cost = 60.0
    #   expect(policy).to receive(:calculate_cost).with(duration, discount).and_return cost
    #   subsidy = 12.20
    #   expect(policy).to receive(:calculate_subsidy).with(duration, discount).and_return subsidy
    #   results = policy.estimate_cost_and_subsidy start_at, end_at
    #   expect(results[:cost]).to eq cost
    #   expect(results[:subsidy]).to eq subsidy
    # end

    # xit "gives the minimum cost without subsidies" do
    #   discount = 0
    #   duration = 15.0
    #   end_at = start_at + duration.minutes
    #   policy.minimum_cost = 60.0
    #   expect(policy).to receive(:calculate_discount).with(start_at, end_at).and_return discount
    #   cost = 15.0
    #   expect(policy).to receive(:calculate_cost).with(duration, discount).and_return cost
    #   subsidy = 0.0
    #   expect(policy).to receive(:calculate_subsidy_for_cost).with(policy.minimum_cost).and_return subsidy
    #   results = policy.estimate_cost_and_subsidy start_at, end_at
    #   expect(results[:cost]).to eq policy.minimum_cost
    #   expect(results[:subsidy]).to eq subsidy
    # end
  end

  describe "calculating with two effective schedule rules, one discounting one not" do
    context "usage cost is more than the policy minimum" do
      before :each do
        policy.product.schedule_rules.first.update_attributes!(
          start_hour: 0,
          end_hour: 24,
          on_sat: false,
          on_sun: false,
        )

        policy.product.reload.schedule_rules << create(:weekend_schedule_rule,
                                                       product: policy.product,
                                                       discount_percent: 25,
                                                       start_hour: 0,
                                                       end_hour: 24)
      end

      it "discounts on one policy" do
        policy.usage_rate = 10
        friday_evening = Time.zone.parse("2017-04-21 23:00")
        saturday_morning = Time.zone.parse("2017-04-22 1:00")
        expect(policy.estimate_cost_and_subsidy(friday_evening, saturday_morning)).to eq(cost: 17.5035, subsidy: 0)
      end
    end

    context "usage cost is less than the policy minimum" do
      before :each do
        policy.minimum_cost = 100.00
        policy.usage_rate = 60.00
        policy.product.schedule_rules << create(:schedule_rule,
                                                product: policy.product,
                                                discount_percent: 20,
                                                start_hour: 17,
                                                end_hour: 24)
        @reservation_start = 1.day.from_now.change hour: 16, min: 15, sec: 0
        @reservation_end = @reservation_start + 1.hour + 30.minutes
      end

      context "without usage subsidies" do
        it "applies the policy minimum cost" do
          costs = policy.estimate_cost_and_subsidy @reservation_start, @reservation_end
          expect(costs[:cost]).to eq policy.minimum_cost
          expect(costs[:subsidy]).to eq 0
        end
      end

      context "with usage subsidies" do
        it "applies the policy minimum cost" do
          expect(policy.usage_rate).to eq(1)
          policy.usage_subsidy = 12.00
          expect(policy.calculate_discount(@reservation_start, @reservation_end)).to eq(0.90)
          expect(policy.usage_rate).to eq(1)
          costs = policy.estimate_cost_and_subsidy @reservation_start, @reservation_end
          expect(costs[:cost]).to eq policy.minimum_cost
          expect(costs[:subsidy]).to eq 20.00
        end
      end
    end
  end

  describe "calculating cost and subsidy" do
    before :each do
      reservation.actual_start_at = now
      reservation.actual_end_at = now + 1.hour
    end

    it 'returns #calculate_cancellation_costs if the reservation was canceled' do
      expect(reservation).to receive(:canceled_at).and_return Time.zone.now
      expect(policy).to receive(:calculate_cancellation_costs).with reservation
      expect(policy).to_not receive :calculate_overage
      expect(policy).to_not receive :calculate_reservation
      expect(policy).to_not receive :calculate_usage
      policy.calculate_cost_and_subsidy reservation
    end

    it 'returns #calculate_usage when configured to charge for usage' do
      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:usage]
      expect(policy).to receive(:calculate_usage).with reservation
      expect(policy).to_not receive :calculate_overage
      expect(policy).to_not receive :calculate_reservation
      expect(policy).to_not receive :calculate_cancellation_costs
      policy.calculate_cost_and_subsidy reservation
    end

    it 'returns #calculate_overage when configured to charge for overage' do
      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:overage]
      expect(policy).to receive(:calculate_overage).with reservation
      expect(policy).to_not receive :calculate_usage
      expect(policy).to_not receive :calculate_reservation
      expect(policy).to_not receive :calculate_cancellation_costs
      policy.calculate_cost_and_subsidy reservation
    end

    it 'returns #calculate_reservation when configured to charge for reservation' do
      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:reservation]
      expect(policy).to receive(:calculate_reservation).with reservation
      expect(policy).to_not receive :calculate_overage
      expect(policy).to_not receive :calculate_usage
      expect(policy).to_not receive :calculate_cancellation_costs
      policy.calculate_cost_and_subsidy reservation
    end

    %w(usage overage).each do |charge_for|
      it "returns nil if actual_start_at is missing and we are charging by #{charge_for}" do
        policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[charge_for.to_sym]
        allow(reservation).to receive(:actual_start_at).and_return nil
        expect(policy.calculate_cost_and_subsidy(reservation)).to be_nil
      end

      it "returns nil if actual_end_at is missing and we are charging by #{charge_for}" do
        policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[charge_for.to_sym]
        allow(reservation).to receive(:actual_start_at).and_return now
        allow(reservation).to receive(:actual_end_at).and_return nil
        expect(policy.calculate_cost_and_subsidy(reservation)).to be_nil
      end
    end

    describe "with a minimum cost, and no usage rate" do
      let(:options) { { usage_rate: 0, minimum_cost: 10 } }
      it 'returns minimum cost if instrument is #free?' do
        expect(policy.calculate_cost_and_subsidy reservation).to eq(cost: 10, subsidy: 0)
      end
    end

    describe "without a minimum cost or a usage rate" do
      let(:options) { { usage_rate: 0, minimum_cost: 0 } }

      it 'returns 0' do
        expect(policy.calculate_cost_and_subsidy reservation).to eq(cost: 0, subsidy: 0)
      end
    end

    it "charges for at least 1 minute of time" do
      policy.attributes = {
        minimum_cost: nil,
        charge_for: InstrumentPricePolicy::CHARGE_FOR[:usage],
      }

      reservation.attributes = {
        actual_start_at: reservation.reserve_start_at,
        actual_end_at: reservation.reserve_start_at + 5.seconds,
      }

      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost]).to be > 0
    end

    it "calculates usage costs precisely" do
      policy.attributes = {
        usage_subsidy: 10.33,
        usage_rate: 73.20,
      }

      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:usage]
      reservation.actual_start_at = reservation.reserve_start_at
      reservation.actual_end_at = reservation.reserve_end_at - 10.minutes
      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost]).to eq(61.to_d)
      expect(new_costs[:subsidy]).to eq(8.61.to_d)
    end

    it "calculates overage costs precisely" do
      policy.attributes = {
        usage_subsidy: 7,
        usage_rate: 25,
      }

      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:overage]
      reservation.actual_start_at = reservation.reserve_start_at
      reservation.actual_end_at = reservation.reserve_end_at + 10.minutes
      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost]).to eq(29.169.to_d)
      expect(new_costs[:subsidy]).to eq(8.169.to_d)
    end

    it "charges for 90 minutes when an hour reservation is started 15 minutes late and goes over the reserved end time by 30 minutes" do
      policy.attributes = {
        usage_subsidy: 0,
        usage_rate: 60,
      }

      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:overage]
      reservation.reserve_start_at = now.change hour: 15, min: 0
      reservation.reserve_end_at = now.change hour: 16, min: 0
      reservation.actual_start_at = reservation.reserve_start_at + 15.minutes
      reservation.actual_end_at = reservation.reserve_end_at + 30.minutes
      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost].round 4).to eq 90
      expect(new_costs[:subsidy].round 4).to eq 0
    end

    it "charges for overage even if the the usage is less than reservation" do
      policy.attributes = {
        usage_subsidy: 0,
        usage_rate: 60,
      }

      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:overage]
      reservation.reserve_start_at = now.change hour: 15, min: 0
      reservation.reserve_end_at = now.change hour: 16, min: 0
      reservation.actual_start_at = reservation.reserve_start_at + 45.minutes
      reservation.actual_end_at = reservation.reserve_end_at + 15.minutes # 30 minutes of use
      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost].round 4).to eq 75
      expect(new_costs[:subsidy].round 4).to eq 0
    end

    it "applies the minimum cost once when in overage" do
      policy.attributes = {
        usage_subsidy: 0,
        usage_rate: 60,
        minimum_cost: 100,
      }

      policy.charge_for = InstrumentPricePolicy::CHARGE_FOR[:overage]
      reservation.reserve_start_at = now.change hour: 15, min: 0
      reservation.reserve_end_at = now.change hour: 17, min: 0
      reservation.actual_start_at = reservation.reserve_start_at + 15.minutes
      reservation.actual_end_at = reservation.reserve_end_at + 30.minutes
      new_costs = policy.calculate_cost_and_subsidy reservation
      expect(new_costs[:cost].round 4).to eq 150
      expect(new_costs[:subsidy].round 4).to eq 0
    end
  end

  describe "determining whether or not a cancellation should be penalized" do
    let(:options) { { usage_rate: 3.0, cancellation_cost: 5.0 } }
    before(:each) { allow(policy.product).to receive(:min_cancel_hours).and_return 3 }

    describe "when it's inside the minimum cancelation window" do
      let(:reservation) { double reserve_start_at: now + 30.minutes, canceled_at: now }

      specify { expect(policy).to be_cancellation_penalty(reservation) }

      it "charges the cancellation cost" do
        expect(policy.calculate_cost_and_subsidy(reservation)).to eq(cost: 5.0, subsidy: 0)
      end
    end

    describe "when it's outside the minimum calcellation window" do
      let(:reservation) { double reserve_start_at: now + 4.hours, canceled_at: now }

      specify { expect(policy).not_to be_cancellation_penalty(reservation) }

      it "does not charge the cancelation cost" do
        expect(policy.calculate_cost_and_subsidy(reservation)).to be_nil
      end
    end
  end
end
