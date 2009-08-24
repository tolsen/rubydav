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
        RubyDav.find elem, 'D:lockentry' do |elems|
          return new(*elems.map { |e| LockEntry.from_elem e })
        end
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

        type_child = RubyDav.find_first elem, 'D:locktype/*'
        scope_child = RubyDav.find_first elem, 'D:lockscope/*'
        raise ArgumentError if type_child.nil? || scope_child.nil?

        type = type_child.name.to_sym
        scope = scope_child.name.to_sym
        
        return new(type, scope)
      end

      RubyDav.gc_protect self, :from_elem
      
    end
  end
end
