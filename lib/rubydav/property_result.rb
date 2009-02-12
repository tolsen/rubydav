module RubyDav

  class PropertyResult

    attr_reader :prop_key, :status, :element, :error

    def initialize prop_key, status, element = nil, error = nil
      @prop_key = prop_key
      @status = status
      @element = element
      @error = error
    end

    def inner_value
      element.nil? ? nil : element.inner_xml
    end

    def success?
      status == '200'
    end

    def value
      element.nil? ? nil : element.to_s_with_ns
    end

  end

end
