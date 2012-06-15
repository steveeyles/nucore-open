module FacilityReservationsHelper
  def reservation_links(reservation)
    links = []
    if reservation.admin? 
      links << link_to(I18n.t('reservations.edit.link'), edit_admin_reservation_path(reservation))
      links << link_to(I18n.t('reservations.delete.link'), facility_instrument_reservation_path(reservation.instrument.facility, reservation.instrument, reservation), :confirm => I18n.t('reservations.delete.confirm'), :method => :delete)
    else
      links << link_to(I18n.t('reservations.switch.start'), order_order_detail_reservation_switch_instrument_path(reservation.order, reservation.order_detail, reservation, :switch => 'on')) if reservation.can_switch_instrument_on?
      links << link_to(I18n.t('reservations.switch.end'), order_order_detail_reservation_switch_instrument_path(reservation.order, reservation.order_detail, reservation, :switch => 'off'), :class => (reservation.order_detail.product.product_accessories.for_acting_as(acting_as?).any? ? :has_accessories : nil)) if reservation.can_switch_instrument_off?
      links << link_to(I18n.t('reservations.edit.link'), edit_facility_order_order_detail_path(reservation.instrument.facility, reservation.order, reservation.order_detail))
      links << link_to_cancel(reservation) if reservation.can_cancel?
    end
    links.join(" | ").html_safe
  end

  def edit_admin_reservation_path(reservation)
    facility_instrument_reservation_edit_admin_path(reservation.instrument.facility, 
                                                    reservation.instrument,
                                                    reservation)
  end

  def link_to_cancel(reservation)
    od = reservation.order_detail
    fee = od.cancellation_fee
    confirmation_message = fee > 0 ? I18n.t('order_details.order_details.cancel.confirm', :fee => number_to_currency(fee)) : I18n.t('reservations.delete.confirm')
    link_to I18n.t('reservations.delete.link'), order_order_detail_path(od.order, od, :cancel => 'cancel'), :method => :put, :confirm => confirmation_message
  end

  MINUTE_TO_PIXEL_RATIO = 0.6
  def datetime_left_position(datetime)
    "#{(datetime - datetime.beginning_of_day) / 60 * MINUTE_TO_PIXEL_RATIO}px"
  end

  def datetime_width(datetime_start, datetime_end)
    "#{(datetime_end - datetime_start) / 60 * MINUTE_TO_PIXEL_RATIO }px"
  end
end