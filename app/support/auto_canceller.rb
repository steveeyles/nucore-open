class AutoCanceller
  AdminStruct = Struct.new(:id)

  def initialize
  end

  def cancel_reservations
    return if cancelable_reservations.none?
    cancelable_reservations.each do |res|
      next if res.order_detail.blank?
      cancel_reservation(res)
    end
  end

  def cancelable_reservations
    @cancelable_reservations ||= Reservation.
      joins(:product, :order_detail).
      where(build_sql, :now => Time.zone.now).
      readonly(false)
  end

  def cancel_reservation(res)
    begin
      res.order_detail.cancel_reservation admin, OrderStatus.cancelled.first, true, true
      res.update_attribute :canceled_reason, 'auto cancelled by system'
    rescue => e
      puts "Could not auto cancel reservation #{res.id}! #{e.message}\n#{e.backtrace.join("\n")}"
    end
  end

private
  def build_sql
    if NUCore::Database.oracle?
      time_condition = <<-CONDITION
        (EXTRACT(MINUTE FROM (:now - reserve_start_at)) +
         EXTRACT(HOUR FROM (:now - reserve_start_at))*60 +
         EXTRACT(DAY FROM (:now - reserve_start_at))*24*60) >= auto_cancel_mins
      CONDITION
    else
      time_condition = " TIMESTAMPDIFF(MINUTE, reserve_start_at, :now) >= auto_cancel_mins"
    end

    where = <<-SQL
        actual_start_at IS NULL
      AND
        actual_end_at IS NULL
      AND
        canceled_at IS NULL
      AND
        auto_cancel_mins IS NOT NULL
      AND
        auto_cancel_mins > 0
      AND
        (state = 'new' OR state = 'inprocess')
      AND
        #{time_condition}
    SQL
  end

  def admin
    # we need something that responds to #id to satisfy OrderDetail#cancel_reservation
    admin = AdminStruct.new
    admin.id = 0
    admin
  end
end