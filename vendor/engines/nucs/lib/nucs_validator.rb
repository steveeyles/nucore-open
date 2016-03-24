class NucsValidator

  include NucsErrors
  include ActiveModel::Validations

  NUCS_BLANK = "-".freeze

  attr_reader :chart_string, :fund, :department, :project, :activity, :program, :chart_field1, :account
  alias_attribute :dept, :department

  validates :fund,         presence: true, length: { is: 3 }, numericality: true
  validates :dept,         presence: true, length: { is: 7 }, numericality: true
  validates :project,      presence: true, if: -> { activity.present? }
  validates :project,      length: { is: 8 }, numericality: true, allow_blank: true
  validates :activity,     length: { is: 2 }, numericality: true, allow_blank: true
  validates :program,      length: { is: 4 }, numericality: true, allow_blank: true
  validates :chart_field1, length: { is: 4 }, numericality: true, allow_blank: true

  def self.pattern_format
    "123-1234567-12345678-12-1234-1234"
  end

  def self.pattern
    /\A[-0-9]*\z/
  end

  #
  # [_chart_string_]
  #   A string that matches +#pattern+. Doesn't include +account+.
  # [_account_]
  #   The account component of a NU chart string
  def initialize(chart_string, account = nil)
    super()
    self.account = account if account
    self.chart_string = chart_string
  end

  #
  # Performs a full NU v9 chart string validation. Returns nil and raises
  # no +Exception+ if this object's +#account+ accepts payment for the
  # components in +#chart_string+. Otherwise one of the +NucsErrors+
  # will be raised.
  #
  # You must have set +@account+ before calling this method!
  def account_is_open!(fulfill_date = nil)
    return if Whitelist.includes?(@chart_string)
    raise NucsErrors::InputError.new("account", nil) unless @account

    # Step 1a & 1b
    return validate_zero_fund! if @fund.start_with?("0")

    # Step 2
    return validate_ge001_components! if revenue_account?

    # Step 3
    validate_program_existence!
    validate_chart_field1_existence!

    components = validate_gl066_components!

    # Step 4
    if grant?
      # Step 6
      tree = NucsGrantsBudgetTree.find_by_account(@account)
      raise UnknownBudgetTreeError.new(@account) unless tree
      validate_gl066_components!(tree.roll_up_node)
    end

    validate_gl066_PAD_components!(components, fulfill_date)
  end

  #
  # Returns a +Hash+ with keys :fund, :dept, :project, :activity,
  # :program, and :chart_field along with their corresponding values
  def components
    {
      fund: fund,
      dept: department,
      project: project,
      activity: activity,
      program: program,
      chart_field1: chart_field1,
    }
  end

  #
  # Compares this object's +#chart string+ components against
  # known values in the DB.
  # [_return_]
  #   true if all known components are found, false otherwise
  def components_exist?
    begin
      validate_ge001_components!
    rescue ValidatorError
      return false
    end

    true
  end

  #
  # Use +#chart_string+ to search the GL066 table for rows with
  # all components. All given components must be present, no more,
  # no less. If today's date falls within the starts_at and expires_at
  # window return the latest value of expires_at that is found.
  # return nil otherwise.
  def latest_expiration
    return Time.zone.now + 3.years if Whitelist.includes?(@chart_string)

    where = {
      fund: @fund,
      department: @department,
    }

    where[:project] = @project if @project
    gls = NucsGl066.find(:all, conditions: where)
    gls.delete_if { |gl| (@project.nil? && gl.project && gl.project != NUCS_BLANK) }

    latest_date = nil

    gls.each do |gl|
      next if gl.expired?
      latest_date = gl.expires_at if latest_date.nil? || gl.expires_at > latest_date
    end

    latest_date
  end

  #
  # Raises a +NucsErrors::InputError+ if +account+ is not a string of 5 digits
  def account=(account)
    account = account.to_s
    raise InputError.new("account", account) if account !~ /^\d{5}$/
    raise BlacklistedError.new("account", account) unless Blacklist.valid_account?(account)
    @account = account
  end

  #
  # Raises a +NucsErrors::InputError+ if +chart_string+ doesn't match +#pattern+
  def chart_string=(chart_string)
    raise InputError.new("chart string", chart_string) unless valid_chart_string?(chart_string)
    @chart_string = chart_string
    parse_chart_string

    raise AccountNumberFormatError.new(errors) unless valid?
    raise BlacklistedError.new("fund", @fund) unless Blacklist.valid_fund?(@fund)
  end

  private

  def parse_chart_string
    results = @chart_string.split("-")
    @fund         = results[0].presence
    @department   = results[1].presence
    @project      = results[2].presence
    @activity     = results[3].presence
    @program      = results[4].presence
    @chart_field1 = results[5].presence
  end

  def revenue_account?
    !(@account !~ /^(4|5)/)
  end

  def grant?
    @project && @project.start_with?("6")
  end

  def valid_chart_string?(chart_string)
    !(chart_string !~ self.class.pattern)
  end

  def validate_zero_fund!
    return validate_ge001_components! if @fund =~ /^02\d$/
    raise TranspositionError.new("011", "110") if @fund == "011"
    raise InputError.new("fund", @fund)
  end

  def validate_chart_field1_existence!
    raise UnknownGE001Error.new("chart field 1", @chart_field1) if @chart_field1 && NucsChartField1.find_by_value(@chart_field1).nil?
  end

  def validate_program_existence!
    raise UnknownGE001Error.new("program", @program) if @program && NucsProgram.find_by_value(@program).nil?
  end

  def validate_ge001_components!
    raise UnknownGE001Error.new("fund", @fund) unless NucsFund.find_by_value(@fund)
    raise UnknownGE001Error.new("department", @department) unless NucsDepartment.find_by_value(@department)
    raise UnknownGE001Error.new("project", @project) if @project && NucsProjectActivity.find_by_project(@project).nil?
    raise UnknownGE001Error.new("activity", @activity) if @activity && NucsProjectActivity.find_by_activity(@activity).nil?
    validate_program_existence!
    validate_chart_field1_existence!
  end

  def validate_gl066_components!(account = nil)
    where = ActiveSupport::OrderedHash[:fund, @fund, :department, @department]
    where[:activity] = @activity if @activity && grant?
    where[:project] = @project if @project
    where[:account] = account if account
    gls = NucsGl066.where(where).all
    raise UnknownGL066Error.new(where) if gls.empty?
    gls
  end

  #
  # Validate Project, Activity, and date components
  def validate_gl066_PAD_components!(gls, fulfill_date = nil)
    validate_activity = grant?
    validate_project = !@project.blank?

    raise InputError.new("activity", nil) if @project && @activity.blank?
    raise UnknownGL066Error.new("activity", @activity) if validate_activity && !gls.any? { |gl| gl.activity == @activity }
    raise UnknownGL066Error.new("project", @project) if validate_project && !gls.any? { |gl| gl.project == @project }

    # invalidate on expiration date if:
    # * we are given an order fulfillment date and the order was fulfilled after the chart string expired
    # * we are given an order fulfillment date and we are outside the 90 day grace period
    # * no fulfillment date was given and all chart string records are expired
    # for more background see http://pm.tablexi.com/issues/49243
    if gls.all?(&:expired?) && (fulfill_date.blank? || gls.all? { |gl| fulfill_date.to_date > gl.expires_at.to_date || gl.expires_at.to_date + 90.days < Date.today })
      raise DatedGL066Error.new("is expired or not yet active")
    end

    fund_i = @fund.to_i

    # this logic implements the relevant rules found in AcctngChartStringConstructionRules.pdf
    # Note: funds less than 100 are blacklisted
    if fund_i >= 100 && fund_i <= 169
      raise NotAllowedError.new("project") if validate_project && @project
      raise NotAllowedError.new("activity") if validate_activity && @activity
    elsif fund_i >= 170 && fund_i <= 179
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("1")
    elsif fund_i >= 191 && fund_i <= 199
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("6")
    elsif fund_i >= 300 && fund_i <= 320
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("3")
    elsif fund_i >= 410 && fund_i <= 483
      raise InputError.new("activity", @activity) if validate_activity && @activity != "01"
    elsif fund_i >= 500 && fund_i <= 540
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("5")
    elsif fund_i >= 600 && fund_i <= 650
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("6")
    elsif fund_i == 750 || (fund_i >= 700 && fund_i <= 740)
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("7")
    elsif fund_i >= 800 && fund_i <= 840
      raise InputError.new("project", @project) if validate_project && !@project.start_with?("8")
    end
  end

end
