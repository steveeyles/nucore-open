require "rails_helper"

RSpec.describe Order do
  let(:facility) { @facility }

  before(:each) do
    @facility = FactoryGirl.create(:facility)
    @facility_account = @facility.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
    @price_group = FactoryGirl.create(:price_group, facility: facility)
    @order_status = FactoryGirl.create(:order_status)
    @service      = @facility.services.create(FactoryGirl.attributes_for(:service, initial_order_status_id: @order_status.id, facility_account_id: @facility_account.id))
    @service_pp   = FactoryGirl.create(:service_price_policy, product: @service, price_group: @price_group)
    @user         = FactoryGirl.create(:user)
    @pg_member    = FactoryGirl.create(:user_price_group_member, user: @user, price_group: @price_group)
    @account      = FactoryGirl.create(:nufs_account, account_users_attributes: account_users_attributes_hash(user: @user))
    @order        = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, account: @account, facility: @facility))
  end

  it "should not allow validate if the account type is not allowed by the facility" do
    # facility does not accept credit card accounts
    @facility.accepts_cc = false
    @facility.save
    # create credit card account and link to order
    @cc_account = FactoryGirl.create(:credit_card_account, account_users_attributes: account_users_attributes_hash(user: @user))
    @order = @user.orders.create(FactoryGirl.attributes_for(:order, created_by: @user.id, account: @cc_account, facility: @facility))
    @order.order_details.create(product_id: @service.id, quantity: 1)
    # should not be allowed to purchase with a credit card account
    expect(@order.validate_order!).to be false
  end
end
