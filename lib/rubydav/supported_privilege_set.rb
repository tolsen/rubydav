
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
        privilege_elem = RubyDav::xpath_first elem, 'privilege/*'
        privilege = RubyDav::PropKey.get(privilege_elem.namespace,
                                         privilege_elem.name)
        abstract = !RubyDav::xpath_first(elem, 'abstract').nil?
        description_elem = RubyDav::xpath_first elem, 'description'
        description = RubyDav::xpath_first(description_elem, 'text()').to_s
        language = RubyDav::xpath_first(description_elem, '@xml:lang').to_s
        children = map_from_elem_to_children elem

        return new(privilege, description, language, abstract, *children)
      end

      def map_from_elem_to_children elem
        RubyDav::xpath_match(elem, 'supported-privilege').map do |e|
          from_elem e
        end
      end

      
    end

  end
end

