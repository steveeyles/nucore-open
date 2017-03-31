require "active_support/concern"

module TimeInputable

  extend ActiveSupport::Concern

  FIELDS = {
             date: "%-m/%-d/%Y",
             hour: "%-l",
             min: "%M",
             meridian: "%p"
           }.freeze

  module ClassMethods
    def time_inputable(attr, prefix: attr)
      FIELDS.each do |field, format|
        define_method("#{prefix}_#{field}=") do |val|
          # Allow passing in a Date or Time
          val = val.strftime(format) if val.respond_to?(:strftime)
          time_inputable_hash[attr][field] = val
          load_time_inputable_value(attr)
        end

        define_method("#{prefix}_#{field}") do
          if public_send(attr)
            public_send(attr).strftime(format)
          else
            time_inputable_hash[attr][field]
          end
        end
      end
    end
  end

  private

  def time_inputable_hash
    @time_inputable_hash ||= Hash.new { |hash, key| hash[key] = {} }
  end

  def load_time_inputable_value(attr)
    return unless has_all_time_inputable_fields?(attr)

    t = time_inputable_hash[attr]
    str = "#{t[:date]} #{t[:hour]}:#{t[:min].to_s.rjust(2, '0')} #{t[:meridian]}"
    built_value = Time.strptime(str, "%m/%d/%Y %H:%M %p")
    public_send("#{attr}=", built_value)
  rescue ArgumentError
    nil
  end

  def has_all_time_inputable_fields?(attr)
    FIELDS.keys.all? { |k| time_inputable_hash[attr].key?(k) }
  end

end
