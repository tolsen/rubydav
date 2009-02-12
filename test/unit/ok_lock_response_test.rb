require 'rexml/document'

require 'test/unit/unit_test_helper'

class OkLockResponseTest < RubyDavUnitTestCase
  def test_create
    response = RubyDav::OkLockResponse.create '/foo', '200', {}, @lockdiscovery, :lock
    assert_instance_of RubyDav::LockInfo, response.lockinfo
    assert_equal '/foo', response.lockinfo.root
  end

  def test_initialize
    response = RubyDav::OkLockResponse.new '/foo', '200', {}, @lockdiscovery, :lockinfo
    assert_equal :lockinfo, response.lockinfo
  end

  def test_parse_body
    assert_instance_of(RubyDav::LockInfo,
                       RubyDav::OkLockResponse.parse_body(@lockdiscovery))
  end

  def test_parse_body__bad_body
    assert_raises RubyDav::BadResponseError do
      RubyDav::OkLockResponse.parse_body @bad_lockdiscovery
    end
  end

end

  
    
