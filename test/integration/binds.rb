require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavBindsTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_rebind_collection_onto_parent
    col = 'col'
    response = @request.mkcol(col)
    assert_equal '201', response.status

    col_subcol = col + '/subcol'
    response = @request.mkcol(col_subcol)
    assert_equal '201', response.status

    response = @request.rebind('', 'col', col_subcol, :overwrite => true)
    assert_equal '200', response.status

    response = @request.unbind('', 'col')
    assert_equal '200', response.status
  end
end
