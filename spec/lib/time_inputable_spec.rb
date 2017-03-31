require "spec_helper"
require "time_inputable"

RSpec.describe TimeInputable do
  describe "with no prefix" do
    class TestingInputable
      include TimeInputable
      attr_accessor :actual_start_at
      time_inputable :actual_start_at
    end

    describe "setting times" do
      subject { TestingInputable.new }

      it "pulls the normal date if it is there" do
        subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
      end

      it "sets the time" do
        subject.actual_start_at_date = "03/12/2016"
        subject.actual_start_at_hour = "2"
        subject.actual_start_at_min = "23"
        subject.actual_start_at_meridian = "PM"

        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
      end

      describe "when given a time" do
        before do
          subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
        end

        it "sets the individual sections" do
          expect(subject.actual_start_at_date).to eq("3/12/2016")
          expect(subject.actual_start_at_hour).to eq("2")
          expect(subject.actual_start_at_min).to eq("23")
          expect(subject.actual_start_at_meridian).to eq("PM")
        end
      end

      describe "when we set only a few fields" do
        before do
          subject.actual_start_at_date = "3/3/2016"
          subject.actual_start_at_hour = "12"
        end

        it "can still return those values" do
          expect(subject.actual_start_at_date).to eq("3/3/2016")
          expect(subject.actual_start_at_hour).to eq("12")
        end
      end
    end
  end

  describe "with a prefix" do
    class TestingInputableWithPrefix
      include TimeInputable
      attr_accessor :actual_start_at
      time_inputable :actual_start_at, prefix: :actual_start
    end

    describe "setting times" do
      subject { TestingInputableWithPrefix.new }

      it "pulls the normal date if it is there" do
        subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
      end

      it "sets the time" do
        subject.actual_start_date = "03/12/2016"
        subject.actual_start_hour = "2"
        subject.actual_start_min = "23"
        subject.actual_start_meridian = "PM"

        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
      end

      describe "when given a time" do
        before do
          subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
        end

        it "sets the individual sections" do
          expect(subject.actual_start_date).to eq("3/12/2016")
          expect(subject.actual_start_hour).to eq("2")
          expect(subject.actual_start_min).to eq("23")
          expect(subject.actual_start_meridian).to eq("PM")
        end
      end

      describe "when we set only a few fields" do
        before do
          subject.actual_start_date = "3/3/2016"
          subject.actual_start_hour = "12"
        end

        it "can still return those values" do
          expect(subject.actual_start_date).to eq("3/3/2016")
          expect(subject.actual_start_hour).to eq("12")
        end
      end
    end
  end

  describe "with multipe fields" do
    class TestingInputable
      include TimeInputable
      attr_accessor :actual_start_at, :reserve_start_at
      time_inputable :actual_start_at
      time_inputable :reserve_start_at
    end

    describe "setting times" do
      subject { TestingInputable.new }

      it "pulls the normal date if it is there" do
        subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
        subject.reserve_start_at = Time.new(2015, 2, 14, 9, 49)

        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
        expect(subject.reserve_start_at).to eq(Time.new(2015, 2, 14, 9, 49))
      end

      it "sets the time" do
        subject.actual_start_at_date = "03/12/2016"
        subject.actual_start_at_hour = "2"
        subject.actual_start_at_min = "23"
        subject.actual_start_at_meridian = "PM"

        subject.reserve_start_at_date = "09/24/2015"
        subject.reserve_start_at_hour = "9"
        subject.reserve_start_at_min = "49"
        subject.reserve_start_at_meridian = "AM"

        expect(subject.actual_start_at).to eq(Time.new(2016, 3, 12, 14, 23))
        expect(subject.reserve_start_at).to eq(Time.new(2015, 9, 24, 9, 49))
      end

      describe "when given a time" do
        before do
          subject.actual_start_at = Time.new(2016, 3, 12, 14, 23)
          subject.reserve_start_at = Time.new(2015, 2, 14, 9, 49)
        end

        it "sets the individual sections" do
          expect(subject.actual_start_at_date).to eq("3/12/2016")
          expect(subject.actual_start_at_hour).to eq("2")
          expect(subject.actual_start_at_min).to eq("23")
          expect(subject.actual_start_at_meridian).to eq("PM")

          expect(subject.reserve_start_at_date).to eq("2/14/2015")
          expect(subject.reserve_start_at_hour).to eq("9")
          expect(subject.reserve_start_at_min).to eq("49")
          expect(subject.reserve_start_at_meridian).to eq("AM")
        end
      end
    end
  end
end
