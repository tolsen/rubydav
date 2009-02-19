
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

  end
end
