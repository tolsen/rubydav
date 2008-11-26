require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavRedirectTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_mkredirectref
    # create a redirectref
    response = @request.mkredirectref('redirect', 'http://www.example.com')
    assert_equal '201', response.status

    # RFC 4437. Section 6 - If no redirect-lifetime is specified,
    # the server must behave as if DAV:temporary was specified.
    # test that we get 302 with the right headers
    response = @request.get('redirect')
    assert_equal '302', response.status
    assert_equal 'http://www.example.com', response.location
    assert_equal 'http://www.example.com', response.redirectref

    # cleanup
    response = @request.delete('redirect', :apply_to_redirect_ref => true)
    assert_equal '204', response.status
  end

  def test_mkredirectref_permanent
    # create a redirectref
    response = @request.mkredirectref('redirect-perm', 'http://www.example.com', :lifetime => :permanent)
    assert_equal '201', response.status

    # test that we get 301 with the right headers
    response = @request.get('redirect-perm')
    assert_equal '301', response.status
    assert_equal 'http://www.example.com', response.location
    assert_equal 'http://www.example.com', response.redirectref

    # cleanup
    response = @request.delete('redirect-perm', :apply_to_redirect_ref => true)
    assert_equal '204', response.status
  end

  def test_redirect_properties
    # create a redirectref
    response = @request.mkredirectref('test-reftarget', 'http://www.example.com')
    assert_equal '201', response.status

    # check the DAV:reftarget, DAV:redirect-lifetime properties
    response = @request.propfind('test-reftarget', 0, :reftarget, :"redirect-lifetime", :apply_to_redirect_ref => true)
    assert_equal '207', response.status
    assert_xml_txt_equal '<D:href xmlns:D="DAV:">http://www.example.com</D:href>', response.propertyhash[reftarget_key]
    assert_xml_txt_equal '<D:temporary xmlns:D="DAV:"/>', response.propertyhash[redirect_lifetime_key]

    # cleanup
    response = @request.delete('test-reftarget', :apply_to_redirect_ref => true)
    assert_equal '204', response.status
  end

  def reftarget_key
    RubyDav::PropKey.get("DAV:", "reftarget")
  end
   
  def redirect_lifetime_key
    RubyDav::PropKey.get("DAV:", "redirect-lifetime")
  end

  def assert_xml_txt_equal xml_txt, xml
    doc = REXML::Document.new xml_txt
    assert_xml_equal doc, xml
  end
end
