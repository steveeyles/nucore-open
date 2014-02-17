require 'spec_helper'

describe JxmlRenderer do

  let(:weekday) { Date.parse("2013-02-14") }
  let(:weekend) { Date.parse("2013-02-16") }


  describe "rendering with respect to today's date" do
    it 'should not render on weekends' do
      Date.stub(:today).and_return weekend
      Journal.should_not_receive :where
      JxmlRenderer.render '/tmp'
    end

    it 'should not render on holidays' do
      JxmlHoliday.create! :date => weekday
      Date.stub(:today).and_return weekday
      Journal.should_not_receive :where
      JxmlRenderer.render '/tmp'
    end

    it 'should render on a regular weekday' do
      Date.stub(:today).and_return weekday

      # force #render to return on empty Journal#where query
      ar = double 'active record relation'
      ar.stub(:all).and_return []
      Journal.stub(:where).and_return ar

      Journal.should_receive :where
      JxmlRenderer.render '/tmp'
    end
  end


  describe 'rendering' do

    let :journal_mock do
      mock = double 'Journal'
      mock.stub :journal_rows
      mock
    end

    let :ar_mock do
      mock = double 'ActiveRecord::Relation'
      mock.stub(:all).and_return [ journal_mock ]
      mock
    end

    let :av_mock do
      mock = double 'ActionView::Base'
      mock.stub :render
      mock.stub(:view_paths).and_return([])
      mock.stub(:assign)
      mock
    end

    before :each do
      Journal.stub(:where).and_return ar_mock
      ActionView::Base.stub(:new).and_return av_mock

      FileUtils.stub :mv
      File.stub(:open).and_yield []
    end


    describe 'argument effects' do
      it 'should not move a file when to_dir param is nil' do
        FileUtils.should_not_receive :mv
        JxmlRenderer.render '/tmp'
      end

      it 'should not move a file when to_dir param is nil' do
        FileUtils.should_receive :mv
        JxmlRenderer.render '/tmp', '/tmp'
      end
    end


    describe 'query window' do
      it 'should make Friday the start day when running after the weekend' do
        JxmlHoliday.create! :date => weekend
        JxmlHoliday.create! :date => weekend + 1.day
        friday = weekend - 1.day
        monday = weekend + 2.day
        it_should_create_the_window friday, monday
      end

      it 'should make 2 days ago the start day when running day after a holiday' do
        JxmlHoliday.create! :date => weekday
        before_holiday = weekday - 1.day
        after_holiday = weekday + 1.day
        it_should_create_the_window before_holiday, after_holiday
      end

      def it_should_create_the_window(window_start, window_end)
        Date.stub(:today).and_return window_end
        start_date = Time.zone.parse("#{window_start.to_s} 17:00:00")
        end_date = Time.zone.parse("#{window_end.to_s} 17:00:00")
        Journal.should_receive(:where).with 'created_at >= ? AND created_at < ? AND is_successful IS NULL', start_date, end_date
        JxmlRenderer.render '/tmp'
      end
    end


    it 'should raise an error if no from_dir is specified' do
      lambda { JxmlRenderer.render }.should raise_error
    end

    it "should create an ActionView with this engine's template" do
      templates_path = File.expand_path '../../app/views', File.dirname(__FILE__)
      ActionView::Base.should_receive(:new)
      JxmlRenderer.render '/tmp'
    end

    it 'should open the correct file' do
      from_dir = '/tmp'
      today = Date.today.to_s
      xml_name = "#{today.gsub(/-/,'')}_CCC_UPLOAD.XML"
      xml_src = File.join(from_dir, xml_name)
      File.should_receive(:open).with(xml_src, 'w')
      JxmlRenderer.render '/tmp'
    end

    it "should render this engine's templates" do
      av_mock.should_receive(:assign).with(
        :journal => journal_mock, :journal_rows => journal_mock.journal_rows
      )
      av_mock.should_receive(:render).with(
        :template => 'facility_journals/show.xml.haml'
      )

      av_mock.should_receive(:render).with(
        :template => 'facility_journals/jxml.text.haml'
      )

      JxmlRenderer.render '/tmp'
    end

  end

end
