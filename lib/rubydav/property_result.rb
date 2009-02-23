require File.dirname(__FILE__) + '/acl'
require File.dirname(__FILE__) + '/current_user_privilege_set'
require File.dirname(__FILE__) + '/prop_key'


module RubyDav

  class PropertyResult

    attr_reader :prop_key, :status, :element, :error

    def acl
      return nil if prop_key != PropKey.get('DAV:', 'acl')
      return Acl.from_elem(element)
    end

    def current_user_privilege_set
      return nil if prop_key != PropKey.get('DAV:', 'current-user-privilege-set')
      return CurrentUserPrivilegeSet.from_elem(element)
    end

    alias cups current_user_privilege_set

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
      status == '200'
    end

    def supported_privilege_set
      return nil if prop_key != PropKey.get('DAV:', 'supported-privilege-set')
      return SupportedPrivilegeSet.from_elem(element)
    end

    def value
      element.nil? ? nil : element.to_s_with_ns
    end

  end

end
