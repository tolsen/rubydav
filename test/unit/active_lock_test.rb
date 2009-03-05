require 'rexml/document'

require 'test/unit/unit_test_helper'

require 'lib/rubydav/active_lock'

class ActiveLockTest < RubyDavUnitTestCase
  
  def element_with_text name, text
    element = REXML::Element.new name
    element.add_namespace 'D:', 'DAV:'
    element.text = text
    return element
  end

  def locktoken_element
    xml = "<D:locktoken xmlns:D='DAV:'><D:href>myfancylocktoken</D:href></D:locktoken>"
    return body_root_element(xml)
  end

  def setup
    super
    @active_lock =
      RubyDav::ActiveLock.new(:write, :exclusive, 0, 10000,
                              '<D:href>http://example.org/~ejw/contact.html</D:href>',
                              'urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                              '/foo/bar')

    @activelock_str = <<EOS
<D:activelock xmlns:D="DAV:"> 
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
EOS

    # This one is missing D:locktype, a required element
    @bad_activelock_str = <<EOS
<D:activelock xmlns:D="DAV:"> 
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
EOS
  end

  def test_eql__equal
    active_lock2 =
      RubyDav::ActiveLock.new(:write, :exclusive, 0, 10000,
                              '  <D:href>http://example.org/~ejw/contact.html</D:href> ',
                              'urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                              '/foo/bar')
    assert_equal @active_lock, active_lock2
  end

  def test_eql__not_equal
    assert_not_equal @active_lock, nil
    
    active_lock2 =
      RubyDav::ActiveLock.new(:write, :shared, 0, 20000,
                              '<D:href>http://example.org/~ejw/contact.html</D:href>',
                              'urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                              '/foo/bar')
    assert_not_equal @active_lock, active_lock2
  end

  def test_from_elem
    active_lock =
      RubyDav::ActiveLock.from_elem body_root_element(@activelock_str)
    assert_instance_of RubyDav::ActiveLock, active_lock
    assert_equal :write, active_lock.type
    assert_equal :exclusive, active_lock.scope
    assert_equal RubyDav::INFINITY, active_lock.depth

    assert_xml_matches active_lock.owner do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D :href, 'http://example.org/~ejw/contact.html'
    end
    
    assert_equal('urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                 active_lock.token)
    assert_equal('http://example.com/workspace/webdav/proposal.doc',
                 active_lock.root)
    assert_equal 604800, active_lock.timeout
  end

  def test_from_elem__bad_root
    body = <<EOS
  <?xml version="1.0" encoding="utf-8" ?> 
  <D:badroot xmlns:D="DAV:"> 
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
  </D:badroot> 
EOS

    element = body_root_element body
    assert_raises(ArgumentError) { RubyDav::ActiveLock.from_elem element }
  end

  def test_from_elem__missing_optional
    body = <<EOS
<D:activelock xmlns:D='DAV:'> 
  <D:locktype><D:write/></D:locktype> 
  <D:lockscope><D:exclusive/></D:lockscope> 
  <D:depth>infinity</D:depth> 
  <D:owner> 
    <D:href>http://example.org/~ejw/contact.html</D:href> 
  </D:owner> 
  <D:timeout>Second-604800</D:timeout> 
  <D:lockroot> 
    <D:href
    >http://example.com/workspace/webdav/proposal.doc</D:href>
  </D:lockroot> 
</D:activelock> 
EOS

    active_lock = RubyDav::ActiveLock.from_elem body_root_element(body)
    assert_nil active_lock.token
  end

  def test_from_elem__missing_required
    element = body_root_element(@bad_activelock_str)
    assert_raises(ArgumentError) { RubyDav::ActiveLock.from_elem element }
  end

  def test_initialize
    assert_equal :write, @active_lock.type
    assert_equal :exclusive, @active_lock.scope
    assert_equal 0, @active_lock.depth
    assert_equal 10000, @active_lock.timeout
    assert_equal('<D:href>http://example.org/~ejw/contact.html</D:href>',
                 @active_lock.owner)
    assert_equal('urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                 @active_lock.token)
    assert_equal '/foo/bar', @active_lock.root
  end

  def test_parse_depth__bad
    depth = element_with_text 'depth', 'bad'
    assert_raises ArgumentError do
      RubyDav::ActiveLock.parse_depth depth
    end
  end

  def test_parse_depth__depth_0
    depth = element_with_text 'depth', '0'
    assert_equal 0, RubyDav::ActiveLock.parse_depth(depth)
  end

  def test_parse_depth__depth_1
    depth = element_with_text 'depth', '1'
    assert_equal 1, RubyDav::ActiveLock.parse_depth(depth)
  end

  def test_parse_depth__depth_infinity
    depth = element_with_text 'depth', 'infinity'
    assert_equal RubyDav::INFINITY, RubyDav::ActiveLock.parse_depth(depth)
  end

  def test_parse_element_with_href
    assert_equal('myfancylocktoken',
                 RubyDav::ActiveLock.parse_element_with_href(locktoken_element))
  end

  def test_parse_element_with_href__bad
    missing_href = element_with_text 'locktoken', 'no href here'
    assert_raises ArgumentError do
      RubyDav::ActiveLock.parse_element_with_href missing_href
    end
  end

  def test_parse_timeout__bad_seconds
    bad_timeout = element_with_text 'timeout', 'Second-Foo'
    assert_raises ArgumentError do
      RubyDav::ActiveLock.parse_timeout bad_timeout
    end
  end

  def test_parse_timeout__bad_text
    bad_timeout = element_with_text 'timeout', 'Foo!'
    assert_raises ArgumentError do
      RubyDav::ActiveLock.parse_timeout bad_timeout
    end
  end
  
  def test_parse_timeout__infinite
    infinite_timeout = element_with_text 'timeout', 'Infinite'
    assert_equal(RubyDav::INFINITY,
                 RubyDav::ActiveLock.parse_timeout(infinite_timeout))
  end

  def test_parse_timeout__seconds
    five_min_timeout = element_with_text 'timeout', 'Second-300'
    assert_equal 300, RubyDav::ActiveLock.parse_timeout(five_min_timeout)
  end

    
end

