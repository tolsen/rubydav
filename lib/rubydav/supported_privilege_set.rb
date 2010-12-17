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
        children = RubyDav.dav_elements_hash(elem, 'privilege',
                                             'abstract', 'description')
        
        privilege_child = RubyDav.first_element children['privilege']
        privilege = RubyDav.element_to_propkey privilege_child

        abstract = children.include? 'abstract'

        description = children['description'].content
        language = RubyDav.xml_lang children['description']
        children = map_from_elem_to_children elem

        return new(privilege, description, language, abstract, *children)
      end

      def map_from_elem_to_children elem
        return RubyDav.elements_named(elem, 'supported-privilege').map do |e|
          from_elem e
        end
      end

    end

  end
  
end

