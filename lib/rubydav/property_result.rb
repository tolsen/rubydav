require File.dirname(__FILE__) + '/prop_key'


module RubyDav

  class PropertyResult

    attr_reader :prop_key, :status, :element, :error

    def eql? other
      other.instance_of?(PropertyResult) &&
        prop_key == other.prop_key &&
        status.to_sym == other.status.to_sym &&
        value == other.value &&
        error == other.error
    end

    alias == eql?

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
      (status.to_i / 100) == 2
    end

    def value
      element.nil? ? nil : element.to_s_with_ns
    end

    class << self

      def define_class_reader method_name, klass, prop_name, namespace = 'DAV:'
        define_method method_name do
          return nil if prop_key != PropKey.get(namespace, prop_name)
          begin
            return klass.from_elem(element)
          rescue ArgumentError
            raise BadResponseError
          end
        end
      end
    end
    

  end

end
