require 'test/unit/unit_test_helper'

require 'lib/rubydav/lock_discovery'

class LockDiscoveryTest < RubyDavUnitTestCase

  def setup
    super

    @lockdiscovery_str = <<EOS
<D:lockdiscovery xmlns:D='DAV:'> 
 <D:activelock> 
  <D:locktype><D:write/></D:locktype> 
  <D:lockscope><D:exclusive/></D:lockscope> 
  <D:depth>0</D:depth> 
  <D:owner>Jane Smith</D:owner> 
  <D:timeout>Infinite</D:timeout> 
  <D:locktoken> 
    <D:href
>urn:uuid:f81de2ad-7f3d-a1b2-4f3c-00a0c91a9d76</D:href>
  </D:locktoken> 
  <D:lockroot> 
    <D:href>http://www.example.com/container/</D:href> 
  </D:lockroot> 
 </D:activelock>
 <D:activelock> 
   <D:locktype><D:write/></D:locktype> 
   <D:lockscope><D:exclusive/></D:lockscope> 
   <D:depth>infinity</D:depth> 
   <D:owner> 
     <D:href>http://example.org/~ejw/contact.html</D:href> 
   </D:owner> 
   <D:timeout>Second-604800</D:timeout> 
   <D:locktoken> 
     <D:href
     >urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4</D:href> 
   </D:locktoken> 
   <D:lockroot> 
     <D:href
     >http://example.com/workspace/webdav/proposal.doc</D:href> 
   </D:lockroot> 
 </D:activelock> 
</D:lockdiscovery>
EOS

    @lock_discovery = RubyDav::LockDiscovery.new :lock1, :lock2
  end

  def test_from_elem
    elem = body_root_element @lockdiscovery_str
    lock_discovery = RubyDav::LockDiscovery.from_elem elem
    lock_discovery.locks.each do |l|
      assert_instance_of RubyDav::ActiveLock, l
    end
  end

  def test_initialize
    assert_instance_of RubyDav::LockDiscovery, @lock_discovery
    assert_equal [:lock1, :lock2], @lock_discovery.locks
  end
  
end

