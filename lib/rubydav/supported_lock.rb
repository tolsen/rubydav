require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class SupportedLock

    attr_reader :entries

    def initialize *entries
      @entries = entries
    end

    class << self

      def from_elem elem
        RubyDav.assert_elem_name elem, 'supportedlock'

        entries = RubyDav.elements_named(elem, 'lockentry').map do |le|
          LockEntry.from_elem le
        end

        return new(*entries)
      end
    end

    [ :supportedlock, :supported_lock ].each do |method_name|
      PropertyResult.define_class_reader method_name, self, 'supportedlock'
    end
  end


  class LockEntry
    
    attr_reader :scope, :type

    def initialize type, scope
      @type = type
      @scope = scope
    end

    class << self

      def from_elem elem
        RubyDav.assert_elem_name elem, 'lockentry'

        args = ['locktype', 'lockscope'].map do |name|
          child = RubyDav.first_element_named elem, name
          raise ArgumentError if child.nil?
          grandchild = RubyDav.first_element child
          raise ArgumentError if grandchild.nil?
          next grandchild.name.to_sym
        end
        
        return new(*args)
      end

    end
  end
end
