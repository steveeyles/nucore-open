require "spec_helper"
require "controller_spec_helper"

describe InstrumentsController do
  let(:facility) { @authable }
  let(:instrument) { @instrument }

  render_views

  it "should route" do
    { :get => "/facilities/alpha/instruments" }.should route_to(:controller => 'instruments', :action => 'index', :facility_id => 'alpha')
    { :get => "/facilities/alpha/instruments/1/manage" }.should route_to(:controller => 'instruments', :action => 'manage', :id => '1', :facility_id => 'alpha')
  end

  before(:all) { create_users }

  before(:each) do
    @authable         = FactoryGirl.create(:facility)
    @facility_account = @authable.facility_accounts.create(FactoryGirl.attributes_for(:facility_account))
    @instrument       = FactoryGirl.create(:instrument,
                                              :facility => @authable,
                                              :facility_account => @facility_account,
                                              :no_relay => true)
    @params={ :id => @instrument.url_name, :facility_id => @authable.url_name }
    @instrument_pp = create :instrument_price_policy, product: @instrument, price_group: @nupg
  end

  context "index" do
    before :each do
      @method=:get
      @action=:index
      @params.delete(:id)
    end

    it_should_allow_operators_only do |user|
      assigns[:instruments].should == [@instrument]
      response.should render_template('instruments/index')
    end
  end

  describe "public_schedule" do
    before :each do
      @method = :get
      @action = :public_schedule
      @params[:instrument_id] = @params[:id]
      @params.delete(:id)
    end

    it 'should not require login' do
      do_request
      response.should be_success
    end

    it 'should set the instrument' do
      do_request
      assigns[:instrument].should == @instrument
    end

    it 'should not have html tags in title' do
      do_request
      response.body.should match('<title>[^<>]+</title>')
    end
  end

  context "manage" do
    before :each do
      @method=:get
      @action=:manage
    end

    it_should_allow_operators_only do |user|
      response.should render_template('instruments/manage')
    end
  end

  context "show" do
    before :each do
      @method = :get
      @action = :show
    end

    it_should_allow :guest, "but not add to cart" do
      expect(assigns[:instrument]).to eq(instrument)
      assert_redirected_to facility_path(facility)
    end

    context "when it needs a valid account" do
      before :each do
        instrument.schedule_rules.create(attributes_for(:schedule_rule))
      end

      context "without a valid account" do
        before(:each) do
          maybe_grant_always_sign_in :director
          do_request
        end

        it "fails" do
          expect(flash).to be_present
          assert_redirected_to facility_path(facility)
        end
      end

      context "with a valid account" do
        before(:each) do
          add_account_for_user(:director, instrument)
          maybe_grant_always_sign_in :director
          do_request
        end

        it "succeeds" do
          expect(flash).to be_empty
          assert_redirected_to(
            add_order_path(
              Order.all.last,
              order: { order_details: [ product_id: instrument.id, quantity: 1 ] },
            )
          )
        end
      end
    end

    context "when it needs schedule rules" do
      before :each do
        facility_operators.each do |operator|
          add_account_for_user(operator, instrument)
        end
        instrument.schedule_rules.create(attributes_for(:schedule_rule))
      end

      it "requires sign in" do
        do_request
        expect(assigns[:instrument]).to eq(instrument)
        expect(session[:requested_params]).to be_present
        assert_redirected_to new_user_session_path
      end

      it_should_allow_all(facility_operators) do
        expect(assigns[:instrument]).to eq(instrument)
        assert_redirected_to(
          add_order_path(
            Order.all.last,
            order: { order_details: [ product_id: instrument.id, quantity: 1 ] },
          )
        )
      end
    end

    context "when the instrument requires approval" do
      before :each do
        instrument.schedule_rules.create(attributes_for(:schedule_rule))
        instrument.update_attributes(requires_approval: true)
      end

      context "if the user is not approved" do
        before(:each) do
          sign_in @guest
          do_request
        end

        context "if the training request feature is enabled", feature_setting: { training_requests: true } do
          it "gives the user the option to submit a request for approval" do
            expect(assigns[:add_to_cart]).to be_blank
            assert_redirected_to(new_facility_product_training_request_path(facility, instrument))
          end
        end

        context "if the training request feature is disabled", feature_setting: { training_requests: false } do
          it "denies access to the user" do
            expect(assigns[:add_to_cart]).to be_blank
            expect(flash[:notice]).to include("instrument requires approval")
          end
        end
      end

      context "if the user is approved" do
        before(:each) do
          @product_user = ProductUser.create(
            product: instrument,
            user: @guest,
            approved_by: @admin.id,
            approved_at: Time.zone.now,
          )
          add_account_for_user(:guest, instrument)
          sign_in @guest
          do_request
        end

        it "adds the instrument to the cart" do
          expect(flash).to be_empty
          expect(assigns[:add_to_cart]).to be true
        end
      end

      context "if the user is an admin" do
        before(:each) do
          add_account_for_user(:admin, instrument)
          sign_in @admin
          do_request
        end

        it "adds the instrument to the cart" do
          expect(assigns[:add_to_cart]).to be true
        end
      end
    end

    context "when the instrument is hidden" do
      before { instrument.update_attribute(:is_hidden, true) }

      it_should_allow_operators_only(:redirect) {}

      context "if acting as a user" do
        before(:each) do
          Instrument.any_instance.stub(:can_purchase?).and_return(true)
          add_account_for_user(:guest, instrument)
          sign_in @admin
          switch_to @guest
          do_request
        end

        it "shows the page if acting as a user" do
          expect(assigns[:instrument]).to eq(instrument)
          expect(assigns[:add_to_cart]).to be true
          expect(response).to be_redirect
        end
      end
    end
  end

  context "new" do
    before :each do
      @method=:get
      @action=:new
    end

    it_should_allow_managers_only do
      expect(assigns(:instrument)).to be_kind_of Instrument
      assigns(:instrument).should be_new_record
      assigns(:instrument).facility.should == @authable
      should render_template 'new'
    end
  end

  context "edit" do
    before :each do
      @method=:get
      @action=:edit
    end

    it_should_allow_managers_only do
      should render_template 'edit'
    end
  end

  context "create" do
    before :each do
      @method=:post
      @action=:create
      @params.merge!(
        :instrument => FactoryGirl.attributes_for(:instrument,
          :facility_account_id => @facility_account.id,
          :control_mechanism => 'manual'
        )
      )
    end

    it_should_allow_managers_only :redirect do
      assert_successful_creation { assigns(:instrument).relay.should be_nil }
    end

    context 'with relay' do

      before :each do
        @params[:instrument].merge!({
          :control_mechanism => 'relay',
          :relay_attributes => {
            :ip => '192.168.1.2',
            :port => 1234,
            :username => 'username',
            :password => 'password',
            :type => RelaySynaccessRevA.name,
            :instrument_id => -1 # nested attributes want something
          }
        })
      end

      it_should_allow :director, 'to create a relay' do
        assert_successful_creation do
          relay=assigns(:instrument).relay
          relay.should be_is_a Relay
          relay.ip.should == @params[:instrument][:relay_attributes][:ip]
          relay.port.should == @params[:instrument][:relay_attributes][:port]
          relay.username.should == @params[:instrument][:relay_attributes][:username]
          relay.password.should == @params[:instrument][:relay_attributes][:password]
          relay.type.should == @params[:instrument][:relay_attributes][:type]
        end
      end

      describe 'relay validations' do
        let!(:instrument2) { create(:instrument, facility: @authable, facility_account: @facility_account, no_relay: true) }
        let!(:old_relay) { create(:relay_syna, :instrument => instrument2) }

        before :each do
          sign_in @admin
          @params[:instrument][:relay_attributes][:ip] = old_relay.ip
          @params[:instrument][:relay_attributes][:port] = old_relay.port
        end

        context "and the relay is taken by a different instrument" do
          it 'does not allow the relay to be used again' do
            do_request
            expect(assigns(:instrument)).to_not be_persisted
            expect(assigns(:instrument).errors).to include(:relay)
          end
        end

        context "and the relay is taken, but on the same shared schedule" do
          it 'allows creation' do
            @params[:instrument][:schedule_id] = instrument2.schedule_id
            do_request
            expect(assigns(:instrument)).to be_persisted
            expect(assigns(:instrument).relay).to be_persisted
          end
        end
      end

    end

    context 'dummy relay' do

      before :each do
        # relay attributes
        @params[:instrument].merge!(:control_mechanism =>'timer')
      end

      it_should_allow :director, 'to create a timer' do
        assert_successful_creation do
          relay=assigns(:instrument).relay
          relay.should be_a Relay
          relay.type.should == RelayDummy.name
        end
      end
    end

    describe 'shared schedule' do
      before :each do
        @schedule = FactoryGirl.create(:schedule, :facility => @authable)
        sign_in @admin
      end

      context 'when wanting a new schedule' do
        before :each do
          @params[:instrument][:schedule_id] = ''
        end

        it 'should create a new schedule' do
          expect { do_request }.to change{ Schedule.count }.by(1)
        end

        it 'should be the newest schedule' do
          do_request
          assigns(:instrument).schedule.should == Schedule.last
        end
      end

      context 'when selecting an existing schedule' do
        before :each do
          @params[:instrument][:schedule_id] = @schedule.id.to_s
        end

        it 'should use the existing schedule' do
          do_request
          assigns(:instrument).schedule.should == @schedule
        end
      end
    end

    context 'fail' do

      before :each do
        @params[:instrument].delete(:name)
      end

      it_should_allow :director, 'and fail when no name is given' do
        expect(assigns(:instrument)).to be_kind_of Instrument
        assigns(:instrument).initial_order_status_id.should == OrderStatus.default_order_status.id
        should render_template 'new'
      end

    end


    def assert_successful_creation
      expect(assigns(:instrument)).to be_kind_of Instrument
      assigns(:instrument).initial_order_status_id.should == OrderStatus.default_order_status.id
      yield
      should set_the_flash
      assert_redirected_to manage_facility_instrument_url(@authable, assigns(:instrument))
    end
  end

  context "update" do
    before :each do
      @method=:put
      @action=:update
      @params.merge!(:instrument => @instrument.attributes.merge!(:control_mechanism =>'manual'))
    end

    context 'no relay' do
      before :each do
        RelaySynaccessRevA.create!(
          :ip => '192.168.1.2',
          :port => 1234,
          :username => 'username',
          :password => 'password',
          :type => RelaySynaccessRevA.name,
          :instrument_id => @instrument.id
        )
      end

      it_should_allow_managers_only :redirect do
        assert_successful_update { assigns(:instrument).reload.relay.should be_nil }
      end
    end

    context 'with relay' do

      before :each do
        @params[:instrument].merge!({
          :control_mechanism => 'relay',
          :relay_attributes => {
            :ip => '192.168.1.2',
            :port => 1234,
            :username => 'username',
            :password => 'password',
            :type => RelaySynaccessRevA.name,
            :instrument_id => @instrument.id
          }
        })
      end

      it_should_allow :director, 'to create a relay' do
        assert_successful_update do
          relay=assigns(:instrument).relay
          relay.should be_is_a Relay
          relay.ip.should == @params[:instrument][:relay_attributes][:ip]
          relay.port.should == @params[:instrument][:relay_attributes][:port]
          relay.username.should == @params[:instrument][:relay_attributes][:username]
          relay.password.should == @params[:instrument][:relay_attributes][:password]
          relay.type.should == @params[:instrument][:relay_attributes][:type]
        end
      end


    end

    context 'dummy relay' do

      before :each do
        @params[:instrument].merge!(:control_mechanism => 'timer')
      end

      it_should_allow :director, 'to create a timer' do
        assert_successful_update do
          relay=assigns(:instrument).relay
          relay.should be_is_a Relay
          relay.ip.should be_nil
          relay.port.should be_nil
          relay.username.should be_nil
          relay.password.should be_nil
          relay.type.should == RelayDummy.name
        end
      end
    end

    def assert_successful_update
      assigns(:header_prefix).should == "Edit"
      assigns(:instrument).should == @instrument
      yield
      should set_the_flash
      assert_redirected_to manage_facility_instrument_url(@authable, assigns(:instrument))
    end
  end

  context "destroy" do
    before :each do
      @method=:delete
      @action=:destroy
    end

    it_should_allow_managers_only :redirect do
      expect(assigns(:instrument)).to be_kind_of Instrument
      #assert_redirected_to manage_facility_instrument_url(@authable, assigns(:instrument))
      assert_redirected_to facility_instruments_url
      dead=false

      begin
        Instrument.find(assigns(:instrument).id)
      rescue
        dead=true
      end

      assert dead
    end
  end

  context "instrument id" do
    before :each do
      @params.merge!(:instrument_id => @params[:id])
      @params.delete(:id)
    end


    context "schedule" do

      before :each do
        @method=:get
        @action=:schedule
      end

      describe 'schedule sharing' do
        let(:instrument2) { FactoryGirl.create(:setup_instrument, facility: @authable,
            schedule: @instrument.schedule) }
        let(:admin_reservation) { FactoryGirl.create(:reservation, product: instrument2,
          reserve_start_at: 2.days.from_now) }
        let(:admin_reservation2) { FactoryGirl.create(:reservation, product: instrument2,
          reserve_start_at: 1.day.from_now) }
        before :each do
          sign_in @admin
          do_request
        end

        it "should show the primary instrument's admin reservation" do
          expect(assigns(:admin_reservations)).to include admin_reservation
        end

        it "should show the second instrument's admin reservation" do
          expect(assigns(:admin_reservations)).to include admin_reservation2
        end

        it "should_allow_operators_only" do
          expect(assigns(:admin_reservations)).to eq([admin_reservation2, admin_reservation])
          should render_template 'schedule'
        end
      end

    end

    context "status" do

      before :each do
        @method=:get
        @action=:instrument_status
      end

      it_should_allow_operators_only

    end

    context 'instrument statuses' do
      before :each do
        # So it doesn't try to actually connect
        RelaySynaccessRevA.any_instance.stub(:query_status).and_return(false)

        @method=:get
        @action=:instrument_statuses
        @instrument_with_relay = FactoryGirl.create(:instrument,
                                              :facility => @authable,
                                              :facility_account => @facility_account,
                                              :no_relay => true)
        @instrument_with_relay.update_attributes(:relay => FactoryGirl.create(:relay_syna, :instrument => @instrument_with_relay))

        @instrument_with_dummy_relay = FactoryGirl.create(:instrument,
                                              :facility => @authable,
                                              :facility_account => @facility_account,
                                              :no_relay => true)
        @instrument_with_dummy_relay.update_attributes(:relay => FactoryGirl.create(:relay_dummy, :instrument => @instrument_with_dummy_relay))

        @instrument_with_dummy_relay.instrument_statuses.create(:is_on => true)
        @instrument_with_bad_relay = FactoryGirl.create(:instrument,
                                              :facility => @authable,
                                              :facility_account => @facility_account,
                                              :no_relay => true)

        @instrument_with_bad_relay.update_attributes(:relay => FactoryGirl.create(:relay_synb, :instrument => @instrument_with_bad_relay))
        RelaySynaccessRevB.any_instance.stub(:query_status).and_raise(StandardError.new('Error!'))
        @instrument_with_bad_relay.relay.update_attribute(:ip, '')
      end

      it_should_allow_operators_only {}

      context 'signed in' do
        before :each do
          maybe_grant_always_sign_in :director
          do_request
          @json_output = JSON.parse(response.body, {:symbolize_names => true})
          @instrument_ids = @json_output.map { |hash| hash[:instrument_status][:instrument_id] }
        end

        it 'should not return instruments without relays' do
          assigns[:instrument_statuses].map(&:instrument).should_not be_include @instrument
          @instrument_ids.should_not be_include @instrument.id
        end
        it 'should include instruments with real relays' do
          assigns[:instrument_statuses].map(&:instrument).should be_include @instrument_with_relay
          @instrument_ids.should be_include @instrument_with_relay.id
        end
        it 'should include instruments with dummy relays' do
          assigns[:instrument_statuses].map(&:instrument).should be_include @instrument_with_dummy_relay
          @instrument_ids.should be_include @instrument_with_dummy_relay.id
        end

        it 'should return an error if the relay is missing a host' do
          assigns[:instrument_statuses].last.instrument.should == @instrument_with_bad_relay
          assigns[:instrument_statuses].last.error_message.should_not be_nil
        end

        it 'should return true for a relay thats switched on' do
          assigns[:instrument_statuses][1].instrument.should == @instrument_with_dummy_relay
          assigns[:instrument_statuses][1].is_on.should be_true
          @json_output[1][:instrument_status][:instrument_id].should == @instrument_with_dummy_relay.id
          @json_output[1][:instrument_status][:is_on].should be_true
        end
        it 'should return false for a relay thats not turned on' do
          assigns[:instrument_statuses].first.instrument.should == @instrument_with_relay
          assigns[:instrument_statuses].first.is_on.should be_false
          @json_output[0][:instrument_status][:is_on].should be_false
          @json_output[0][:instrument_status][:instrument_id].should == @instrument_with_relay.id
        end

        it 'should create a new false instrument status if theres nothing' do
          @instrument_with_relay.reload.instrument_statuses.size.should == 1
        end
        it 'should not create a second true instrument status' do
          @instrument_with_dummy_relay.reload.instrument_statuses.size.should == 1
        end
      end

    end


    context "switch" do

      before :each do
        @method=:get
        @action=:switch
        @params.merge!(:switch => 'on')
      end

      it_should_allow_operators_only

    end
  end
end
