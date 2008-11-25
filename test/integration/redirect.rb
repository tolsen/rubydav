require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavRedirectTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_mkredirectref

    # create a redirectref
    response = @request.mkredirectref('redirect', 'http://limebits.com')
    assert_equal '201', response.status

    # test that we get 302 with the right headers
    response = @request.get('redirect')
    assert_equal '302', response.status
    assert_equal 'http://limebits.com', response.location
    assert_equal 'http://limebits.com', response.redirectref

    # cleanup
    response = @request.delete('redirect', :apply_to_redirect_ref => true)
    assert_equal '204', response.status
  end

end
