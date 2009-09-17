require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class SupportedPrivilegeSet

    attr_reader :supported_privileges

    # returns all descendant privileges as a list of PropKeys
    def all_privileges
      privileges = []
      sp_queue = supported_privileges.dup

      until sp_queue.empty?
        sp = sp_queue.shift
        privileges << sp.privilege
        sp_queue += sp.children
      end

      return privileges
    end

    def initialize *supported_privileges
      @supported_privileges = supported_privileges
    end

    class << self

      def from_elem elem
        new *SupportedPrivilege.map_from_elem_to_children(elem)
      end

    end

    PropertyResult.define_class_reader(:supported_privilege_set, self, 'supported-privilege-set')

  end

  class SupportedPrivilege

    attr_reader :privilege, :description, :language, :children

    def abstract?() @abstract; end

    # language corresponds to the description
    def initialize(privilege, description, language,
                   abstract = false, *children)
      @privilege = privilege
      @description = description
      @language = language
      @abstract = abstract
      @children = children
    end

    class << self
      
      def from_elem elem
        privilege_elem = RubyDav.find_first elem, 'D:privilege/*'
        privilege =
          RubyDav::PropKey.get(RubyDav.namespace_href(privilege_elem),
                               privilege_elem.name)
        abstract = !RubyDav.find_first(elem, 'D:abstract').nil?
        description_elem = RubyDav.find_first elem, 'D:description'
        description = RubyDav.find_first(description_elem, 'text()').to_s
        language = description_elem.lang
        children = map_from_elem_to_children elem

        return new(privilege, description, language, abstract, *children)
      end

      def map_from_elem_to_children elem
        RubyDav.find(elem, 'D:supported-privilege') do |sprivilege_elems|
          return(sprivilege_elems.map { |e| from_elem e })
        end
      end

      RubyDav.gc_protect self, :from_elem
    end

  end
  
end

