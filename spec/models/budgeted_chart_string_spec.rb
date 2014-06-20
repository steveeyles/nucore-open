require 'spec_helper'

describe BudgetedChartString do

  it "should require fund" do
    should validate_presence_of(:fund)
  end

  it "should require dept" do
    should validate_presence_of(:dept)
  end

  it "should require starts_at" do
    should validate_presence_of(:starts_at)
  end

  it "should require expires_at" do
    should validate_presence_of(:expires_at)
  end

  # This import may not be used anymore, but I'm refactoring it to use the new fiscal
  # year setting anyways. -Jason
  context 'import' do
    before :each do
      Settings.financial.fiscal_year_begins = '04-01'
      filename = "#{Rails.root}/spec/files/budgeted_chart_strings1.txt"
      BudgetedChartString.delete_all
      BudgetedChartString.import(filename)
      # should have 2 records plus the 4 test records
      assert_equal 6, BudgetedChartString.count
      # should properly parse account fields and dates
      @bcs1 = (BudgetedChartString.all)[4]
      @bcs2 = BudgetedChartString.last
    end
    after :each do
      Settings.reload!
    end
    it 'should set fields correctly' do
      assert_equal "20080910", @bcs1.starts_at.strftime("%Y%m%d")
      assert_equal "20090831", @bcs1.expires_at.strftime("%Y%m%d")
      assert_equal "191", @bcs1.fund
      assert_equal "1000000", @bcs1.dept
    end
    it 'should set fields correctly including defaulting to fiscal year' do
      assert_equal "20090401", @bcs2.starts_at.strftime("%Y%m%d")
      assert_equal "20100331", @bcs2.expires_at.strftime("%Y%m%d")
      assert_equal "732", @bcs2.fund
      assert_equal "2105600", @bcs2.dept
    end
  end

  context 'Parsing dates with 2-digit years' do
    def parse_date(date_string)
      BudgetedChartString.parse_2_digit_year_date(date_string).strftime('%Y%m%d')
    end

    it 'should parse strings as 21st century dates' do
      expect(parse_date('1JAN00')).to eq('20000101')
      expect(parse_date('08JUN04')).to eq('20040608')
      expect(parse_date('31DEC14')).to eq('20141231')
      expect(parse_date('31MAR49')).to eq('20490331')
      expect(parse_date('05FEB99')).to eq('20990205')
    end
  end
end
