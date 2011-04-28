require 'spec_helper'

describe ServicePricePolicy do
  it "should create a price policy for tomorrow if no policies already exist for that day" do
    should allow_value(Date.today+1).for(:start_date)
  end

  it "should create a price policy for yesterday" do
    should allow_value(Date.today - 1).for(:start_date)
  end

  it "should return cost - subsidy as the total" do
    ipp = ServicePricePolicy.new(:unit_cost => 10.75, :unit_subsidy => 0)
    ipp.unit_total.to_f.should == 10.75
    ipp = ServicePricePolicy.new(:unit_cost => 10.75, :unit_subsidy => 0.75)
    ipp.unit_total.to_f.should == 10
  end

  context "test requiring services" do
    before(:each) do
      @facility         = Factory.create(:facility)
      @facility_account = @facility.facility_accounts.create(Factory.attributes_for(:facility_account))
      @price_group      = @facility.price_groups.create(Factory.attributes_for(:price_group))
      @service             = @facility.services.create(Factory.attributes_for(:service, :facility_account => @facility_account))
      @price_group_product=Factory.create(:price_group_product, :product => @service, :price_group => @price_group, :reservation_window => nil)
    end

    it "should create using factory" do
      # price policy belongs to an service and a price group
      ipp = @service.service_price_policies.create(Factory.attributes_for(:service_price_policy, :price_group => @price_group))
      ipp.should be_valid
    end

    it 'should return the item' do
      ipp = @service.service_price_policies.create(Factory.attributes_for(:service_price_policy, :start_date => Date.today, :price_group_id => @price_group.id))
      ipp.product.should == @service
    end

    it "should create a price policy for today if no active price policy already exists" do
      should allow_value(Date.today).for(:start_date)
      ipp     = @service.service_price_policies.create(:unit_cost => 1, :unit_subsidy => 0, :start_date => Date.today - 7,
                                                 :price_group => @price_group)
      ipp.save_with_validation(false)
      ipp_new = @service.service_price_policies.create(:unit_cost => 1, :unit_subsidy => 0, :start_date => Date.today,
                                                 :price_group => @price_group)
      ipp_new.errors_on(:start_date).should_not be_nil
    end

    it "should not create a price policy for a day that a policy already exists for" do
      ipp     = @service.service_price_policies.create(Factory.attributes_for(:service_price_policy, :start_date => Date.today + 7, :price_group_id => @price_group.id))
      ipp_new = @service.service_price_policies.create(Factory.attributes_for(:service_price_policy, :start_date => Date.today + 7, :price_group_id => @price_group.id))
      ipp_new.errors_on(:start_date).should_not be_nil
    end

    it "should calculate the cost for an 1 service" do
      ipp   = @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today, :price_group_id => @price_group.id)
      costs = ipp.calculate_cost_and_subsidy
      costs[:cost].to_f.should == 10.75
      costs[:subsidy].to_f.should == 0.75
    end

    it "should calculate the cost for multiple service when given a quantity" do
      ipp   = @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today, :price_group_id => @price_group.id)
      costs = ipp.calculate_cost_and_subsidy(2)
      costs[:cost].to_f.should == 21.5
      costs[:subsidy].to_f.should == 1.5
    end

    it 'should estimate the same as calculate' do
      ipp   = @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today, :price_group_id => @price_group.id)
      ipp.estimate_cost_and_subsidy(2).should == ipp.calculate_cost_and_subsidy(2)
    end

    it "should return a cost of nil if the purchase is restricted" do
      @price_group_product.destroy
      ipp = @service.service_price_policies.create(:start_date => Date.today, :price_group_id => @price_group.id)
      ipp.calculate_cost_and_subsidy.should be_nil
    end

    it "should return the date for the current policies" do
      ipp = @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today - 7.days, :price_group_id => @price_group.id)
      ipp.save(false) #save without validations
      @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today + 7.days, :price_group_id => @price_group.id)
      ServicePricePolicy.current_date(@service).to_date.should == Date.today - 7.days

      ipp = @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today, :price_group_id => @price_group.id)
      ipp.save(false) #save without validations
      ServicePricePolicy.current_date(@service).to_date.should == Date.today
    end

    it "should return the date for upcoming policies" do
      @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today, :price_group_id => @price_group.id)
      @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today + 7.days, :price_group_id => @price_group.id)
      @service.service_price_policies.create(:unit_cost => 10.75, :unit_subsidy => 0.75, :start_date => Date.today + 14.days, :price_group_id => @price_group.id)

      ServicePricePolicy.next_date(@service).to_date.should == Date.today + 7.days
      next_dates = ServicePricePolicy.next_dates(@service)
      next_dates.length.should == 2
      next_dates.include?(Date.today + 7.days).should be_true
      next_dates.include?(Date.today + 14.days).should be_true
    end
  end
end
