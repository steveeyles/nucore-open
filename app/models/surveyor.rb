#
# Knows how to talk to NUCore-tweaked Surveyor webapps
# https://github.com/breakpointer/surveyor
class Surveyor < UrlService

  def edit_url(receiver)
    "#{receiver.external_service_receiver.response_data}/take"
  end


  def new_url(receiver)
    "#{location}?receiver_id=#{receiver.id}&product_id=#{receiver.product.url_name}&survey_id=#{id}&facility_id=#{receiver.product.facility.url_name}"
  end

end