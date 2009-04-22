require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavBindsTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_propfind_allprop
    new_file 'file'
    
    # allprop propfind should not return resource-id or parent-set
    response = @request.propfind 'file', 0, :allprop
    assert_equal '207', response.status

    displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    assert response.resources["#{@uri.path}file"].include?(displayname_pk)
    %w(resource-id parent-set).each do |propname|
      pk = RubyDav::PropKey.get 'DAV:', propname
      assert !(response.resources["#{@uri.path}file"].include? pk)
    end
  ensure
    delete_file 'file'
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
