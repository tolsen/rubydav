require 'test/unit/unit_test_helper'

require 'lib/rubydav/sub_response'

class SubResponseTest < RubyDavUnitTestCase

  def setup
    @sr200 = RubyDav::SubResponse.new '/foo/bar', '200'
    @sr201 = RubyDav::SubResponse.new '/foo/bar', '201'
    @sr404 = RubyDav::SubResponse.new '/foo/baz', '404', :error, 'not found'
    @sr301 = RubyDav::SubResponse.new('/foo/foo', '303', nil,
                                      'redirect', '/foo/bar')
  end
    
  def test_initialize
    assert_equal '/foo/bar', @sr200.href
    assert_equal '200', @sr200.status
    assert_nil @sr200.error
    assert_nil @sr200.description
    assert_nil @sr200.location

    assert_equal :error, @sr404.error
    assert_equal 'not found', @sr404.description
    assert_nil @sr404.location

    assert_nil @sr301.error
    assert_equal '/foo/bar', @sr301.location
  end

  def test_success
    assert @sr200.success?
    assert @sr201.success?
    assert !@sr404.success?
    assert !@sr301.success?
  end
end
