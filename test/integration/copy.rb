require 'test/unit'
require 'uri'

require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavCopyTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_copy_coll_retains_destination_resource_id
    # create a small tree of resource at collA
    @request.delete('collA')
    response = @request.mkcol('collA')
    assert_equal '201', response.status

    response = @request.put('collA/file', @stream)
    assert_equal '201', response.status

    response = @request.mkcol('collA/subcoll')
    assert_equal '201', response.status

    response = @request.put('collA/subcoll/file', StringIO.new("A small file"))
    assert_equal '201', response.status

    # create a similar structure at collB
    @request.delete('collB')
    response = @request.mkcol('collB')
    assert_equal '201', response.status

    response = @request.put('collB/file', StringIO.new("Another Small file"))
    assert_equal '201', response.status

    response = @request.mkcol('collB/subcoll')
    assert_equal '201', response.status

    # the two structure differ at this file name
    response = @request.put('collB/subcoll/file1', StringIO.new("smaller file"))
    assert_equal '201', response.status

    # get the resource ids at collB before the copy
    response_before = @request.propfind('collB', RubyDav::INFINITY, :"resource-id")
    assert !response_before.error?

    # copy collA onto collB
    response = @request.copy('collA', 'collB', RubyDav::INFINITY, true)
    assert_equal '204', response.status

    # get the resource ids at collB after the copy
    response_after = @request.propfind('collB', RubyDav::INFINITY, :"resource-id")
    assert !response_after.error?

    # assert that the uuids are retained for these uris
    for uri in ['collB', 'collB/file', 'collB/subcoll']
      assert_equal(response_before[@uri.path + uri][:"resource-id"],
                   response_after[@uri.path + uri][:"resource-id"])
    end

    assert_not_equal(response_before["#{@uri.path}collB/subcoll/file1"][:"resource-id"],
                     response_after["#{@uri.path}collB/subcoll/file"][:"resource-id"])
    assert_nil response_after['collB/subcoll/file1']

    # cleanup
    response = @request.delete('collA', :depth => RubyDav::INFINITY)
    assert_equal '204', response.status
    response = @request.delete('collB', :depth => RubyDav::INFINITY)
    assert_equal '204', response.status
  end

  def test_copy_malformed_destination_uri
    file = 'testcopy'
    new_file file

    uri = URI.parse(@host)
    # try http://host:port../ type malformed URIs
    assert_raises(URI::InvalidURIError) do
      @request.copy(file, uri.scheme+"://"+uri.host+":"+uri.port.to_s+"../", RubyDav::INFINITY, true)
    end
    
    # cleanup
    delete_file file
  end 
end
