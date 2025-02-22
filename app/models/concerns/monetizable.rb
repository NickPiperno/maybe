module Monetizable
  extend ActiveSupport::Concern

  class_methods do
    def monetize(*fields, as: nil, **options)
      fields.each do |field|
        define_method("#{field}_money") do
          value = self.send(field)
          value.nil? ? nil : Money.new(value, currency || Money.default_currency)
        end

        if as
          alias_method as.to_s, "#{field}_money"
        end
      end
    end
  end
end
