require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class CurrentUserPrivilegeSet

    attr_reader :privileges

    def initialize *privileges
      @privileges = privileges
    end

    class << self

      def from_elem elem
        return new(*RubyDav.privilege_elements_to_propkeys(elem))
      end
      
    end

    [ :current_user_privilege_set, :cups ].each do |method_name|
      PropertyResult.define_class_reader(method_name, self,
                                         'current-user-privilege-set')
    end
    

  end
end
