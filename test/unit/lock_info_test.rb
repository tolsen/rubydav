require 'rexml/document'

require 'test/unit/unit_test_helper'

require 'lib/rubydav/lock_info'

class LockInfoTest < RubyDavUnitTestCase
  
  def body_root_element body = @lockdiscovery
    return REXML::Document.new(body).root
  end

  def element_with_text name, text
    element = REXML::Element.new name
    element.add_namespace 'D:', 'DAV:'
    element.text = text
    return element
  end

  def lockdiscovery_element body = @lockdiscovery
    root = body_root_element body
    return REXML::XPath.first(root, 'D:lockdiscovery', 'D' => 'DAV:')
  end

  def locktoken_element
    xml = "<D:locktoken xmlns:D='DAV:'><D:href>myfancylocktoken</D:href></D:locktoken>"
    return body_root_element(xml)
  end

  def setup
    super
    @lock_info =
      RubyDav::LockInfo.new( :type => :write,
                             :scope => :exclusive,
                             :depth => 0,
                             :timeout => 10000,
                             :owner =>
                             '<D:href>http://example.org/~ejw/contact.html</D:href>',
                             :token =>
                             'urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                             :root => '/foo/bar' )
  end

  def test_from_prop_element
    lockinfo = RubyDav::LockInfo.from_prop_element body_root_element
    assert_instance_of RubyDav::LockInfo, lockinfo
  end

  def test_from_prop_element__bad_root
    body = <<EOS
  <?xml version="1.0" encoding="utf-8" ?> 
  <D:badprop xmlns:D="DAV:"> 
    <D:lockdiscovery> 
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
  </D:badprop> 
EOS

    element = body_root_element body
    assert_raises ArgumentError do
      RubyDav::LockInfo.from_prop_element element
    end
  end

  def test_from_lockdiscovery_element
    lockinfo =
      RubyDav::LockInfo.from_lockdiscovery_element lockdiscovery_element
    assert_equal :write, lockinfo.type
    assert_equal :exclusive, lockinfo.scope
    assert_equal RubyDav::INFINITY, lockinfo.depth

    assert_xml_matches lockinfo.owner do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D :href, 'http://example.org/~ejw/contact.html'
    end
    
    assert_equal('urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                 lockinfo.token)
    assert_equal('http://example.com/workspace/webdav/proposal.doc',
                 lockinfo.root)
    assert_equal 604800, lockinfo.timeout
  end

  def test_from_lockdiscovery_element__missing_optional
    body = <<EOS
  <?xml version="1.0" encoding="utf-8" ?> 
  <D:prop xmlns:D="DAV:"> 
    <D:lockdiscovery> 
      <D:activelock> 
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
    </D:lockdiscovery> 
  </D:prop> 
EOS

    lockinfo =
      RubyDav::LockInfo.from_lockdiscovery_element lockdiscovery_element(body)
    assert_nil lockinfo.token
  end

  def test_from_lockdiscovery_element__missing_required
    element = lockdiscovery_element(@bad_lockdiscovery)
    assert_raises ArgumentError do
      RubyDav::LockInfo.from_lockdiscovery_element element
    end
  end

  def test_initialize
    assert_equal :write, @lock_info.type
    assert_equal :exclusive, @lock_info.scope
    assert_equal 0, @lock_info.depth
    assert_equal 10000, @lock_info.timeout
    assert_equal('<D:href>http://example.org/~ejw/contact.html</D:href>',
                 @lock_info.owner)
    assert_equal('urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4',
                 @lock_info.token)
    assert_equal '/foo/bar', @lock_info.root
  end

  def test_parse_depth__bad
    depth = element_with_text 'depth', 'bad'
    assert_raises ArgumentError do
      RubyDav::LockInfo.parse_depth depth
    end
  end

  def test_parse_depth__depth_0
    depth = element_with_text 'depth', '0'
    assert_equal 0, RubyDav::LockInfo.parse_depth(depth)
  end

  def test_parse_depth__depth_1
    depth = element_with_text 'depth', '1'
    assert_equal 1, RubyDav::LockInfo.parse_depth(depth)
  end

  def test_parse_depth__depth_infinity
    depth = element_with_text 'depth', 'infinity'
    assert_equal RubyDav::INFINITY, RubyDav::LockInfo.parse_depth(depth)
  end

  def test_parse_element_with_href
    assert_equal('myfancylocktoken',
                 RubyDav::LockInfo.parse_element_with_href(locktoken_element))
  end

  def test_parse_element_with_href__bad
    missing_href = element_with_text 'locktoken', 'no href here'
    assert_raises ArgumentError do
      RubyDav::LockInfo.parse_element_with_href missing_href
    end
  end

  def test_parse_timeout__bad_seconds
    bad_timeout = element_with_text 'timeout', 'Second-Foo'
    assert_raises ArgumentError do
      RubyDav::LockInfo.parse_timeout bad_timeout
    end
  end

  def test_parse_timeout__bad_text
    bad_timeout = element_with_text 'timeout', 'Foo!'
    assert_raises ArgumentError do
      RubyDav::LockInfo.parse_timeout bad_timeout
    end
  end
  
  def test_parse_timeout__infinite
    infinite_timeout = element_with_text 'timeout', 'Infinite'
    assert_equal(RubyDav::INFINITY,
                 RubyDav::LockInfo.parse_timeout(infinite_timeout))
  end

  def test_parse_timeout__seconds
    five_min_timeout = element_with_text 'timeout', 'Second-300'
    assert_equal 300, RubyDav::LockInfo.parse_timeout(five_min_timeout)
  end

  def test_printXML
    out = ''
    xml = RubyDav::XmlBuilder.generate out
    @lock_info.printXML xml
    assert_xml_matches out do
      xml.xmlns! 'DAV:'
      xml.lockinfo do
        xml.locktype { xml.write }
        xml.lockscope { xml.exclusive }
        xml.owner { xml.href 'http://example.org/~ejw/contact.html' }
      end
    end
  end
    
end

