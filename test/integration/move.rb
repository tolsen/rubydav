require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavCopyTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_dst_overwrite
    response = @request.delete('src')
    response = @request.mkcol('src')
    assert_equal '201', response.status

    response = @request.delete('dst')
    response = @request.mkcol('dst')
    assert_equal '201', response.status

    response = @request.put('dst/file', @stream)
    assert_equal '201', response.status

    lock = lock 'dst/file'

    response = @request.move('src', 'dst', true)
    assert_equal '423', response.status

    response = @request.move('src', 'dst', true, :if => { 'dst/file' => lock.token })
    assert_equal '204', response.status

    response = @request.get('dst/file')
    assert_equal '404', response.status

    response = @request.propfind('dst/file', 0, :'resource-id')
    assert_equal '404', response.status

    response = @request.delete('dst')
    assert_equal '204', response.status
  end
end
