require File.dirname(__FILE__) + '/active_lock'
require File.dirname(__FILE__) + '/property_result'

module RubyDav

  class LockDiscovery

    # locks is a hash from lock_tokens -> active_locks
    attr_reader :locks

    # pass in a list of ActiveLock objects
    def initialize *locks
      @locks = locks.inject({}) { |h, l| h[l.token] = l; h }
    end

    class << self

      def from_elem elem
        RubyDav.assert_elem_name elem, 'lockdiscovery'
        return new(*RubyDav.xpath_match(elem, 'activelock').map do |l|
                     ActiveLock.from_elem l
                   end)
      end

    end

    [ :lockdiscovery, :lock_discovery ].each do |method_name|
      PropertyResult.define_class_reader method_name, self, 'lockdiscovery'
    end
    
  end
end

  
                   
                     
    
