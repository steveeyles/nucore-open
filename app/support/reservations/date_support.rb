# Support for reading/writing reservation and actual start and
# end times using values split across text inputs
module Reservations::DateSupport

  extend ActiveSupport::Concern
  include TimeInputable

  included do
    attr_writer :duration_mins, :actual_duration_mins

    time_inputable :reserve_start_at, prefix: :reserve_start
    time_inputable :reserve_end_at, prefix: :reserve_end
    time_inputable :actual_start_at, prefix: :actual_start
    time_inputable :actual_end_at, prefix: :actual_end

    before_validation :set_all_end_times_from_durations
  end

  def assign_times_from_params(params)
    assign_reserve_from_params(params) if admin_editable?
    assign_actuals_from_params(params) if can_edit_actuals?

    set_all_end_times_from_durations
  end

  def duration_mins
    if @duration_mins
      @duration_mins.to_i
    elsif reserve_end_at && reserve_start_at
      duration_with_seconds_stripped(reserve_start_at, reserve_end_at)
    else
      0
    end
  end

  def actual_duration_mins(base_time = Time.zone.now)
    if @actual_duration_mins
      @actual_duration_mins.to_i
    elsif actual_start_at
      end_at = actual_end_at || base_time
      [duration_with_seconds_stripped(actual_start_at, end_at), 1].max
    else
      0
    end
  end

  private

  def set_all_end_times_from_durations
    set_reserve_end_at
    set_actual_end_at
  end

  def assign_reserve_from_params(params)
    self.reserve_start_at = nil
    self.reserve_end_at = nil
    reserve_attrs = params.slice(:reserve_start_date, :reserve_start_hour, :reserve_start_min, :reserve_start_meridian,
                                 :duration_mins,
                                 :reserve_start_at, :reserve_end_at)

    assign_attributes reserve_attrs
  end

  def assign_actuals_from_params(params)
    self.acual_start_at = nil
    self.acual_end_at = nil

    reserve_attrs = params.slice(:actual_start_date, :actual_start_hour, :actual_start_min, :actual_start_meridian,
                                 :actual_duration_mins,
                                 :actual_start_at, :actual_end_at)

    reserve_attrs.reject! { |_key, value| value.blank? }

    assign_attributes reserve_attrs
  end

  # set reserve_end_at based on duration_mins
  def set_reserve_end_at
    return if reserve_end_at.present? || reserve_start_at.blank? || @duration_mins.blank?

    self.reserve_end_at = reserve_start_at + @duration_mins.to_i.minutes
  end

  def set_actual_end_at
    return if actual_end_at.present? || actual_start_at.blank? || @actual_duration_mins.blank?

    self.actual_end_at = actual_start_at + @actual_duration_mins.to_i.minutes
  end

  def duration_with_seconds_stripped(start_time, end_time)
    ((end_time.change(sec: 0) - start_time.change(sec: 0)) / 60).to_i
  end

end
