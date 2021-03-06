module SplitAccounts

  class AttributeSplitter

    attr_reader :splittable_attributes

    def initialize(*splittable_attributes)
      @splittable_attributes = splittable_attributes
    end

    def split(original_object, split_object, split)
      splittable_attributes.each do |attr|
        split_object.public_send "#{attr}=", floored_amount(split.percent, original_object.public_send(attr))
      end
    end

    def to_a
      splittable_attributes
    end

    private

    def floored_amount(percent, value)
      return BigDecimal(0) if percent == 0 || value.blank?
      amount = BigDecimal(value) * BigDecimal(percent) / 100
      amount.floor(2)
    end

  end

end
