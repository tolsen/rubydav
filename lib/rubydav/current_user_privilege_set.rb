require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class CurrentUserPrivilegeSet

    attr_reader :privileges

    def initialize *privileges
      @privileges = privileges
    end

    class << self

      def from_elem elem
        elems = RubyDav::xpath_match elem, 'privilege/*'
        return new(*elems.map { |p| PropKey.get p.namespace, p.name })
      end
    end

    [ :current_user_privilege_set, :cups ].each do |method_name|
      PropertyResult.define_class_reader(method_name, self,
                                         'current-user-privilege-set')
    end
    

  end
end
