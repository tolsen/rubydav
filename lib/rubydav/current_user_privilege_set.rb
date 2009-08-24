require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class CurrentUserPrivilegeSet

    attr_reader :privileges

    def initialize *privileges
      @privileges = privileges
    end

    class << self

      def from_elem elem
        privileges = nil
        RubyDav.find(elem, 'D:privilege/*') do |elems|
          privileges = elems.map do |p|
            next PropKey.get(RubyDav.namespace_href(p), p.name)
          end
        end
        return new(*privileges)
      end
      
    end

    [ :current_user_privilege_set, :cups ].each do |method_name|
      PropertyResult.define_class_reader(method_name, self,
                                         'current-user-privilege-set')
    end
    

  end
end
