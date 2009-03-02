require File.dirname(__FILE__) + '/active_lock'

module RubyDav

  class LockDiscovery

    attr_reader :locks

    def initialize *locks
      @locks = locks
    end

    class << self

      def from_elem elem
        RubyDav.assert_elem_name elem, 'lockdiscovery'
        return new(*RubyDav.xpath_match(elem, 'activelock').map do |l|
                     ActiveLock.from_elem l
                   end)
      end

    end
  end
end

  
                   
                     
    
