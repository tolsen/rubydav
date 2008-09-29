require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavDeltavTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def href_elem_to_url(href)
    doc = REXML::Document.new(href)
    href = RubyDav.remove_trailing_slashes(doc.root.text)
    "http://#{@uri.host}:#{@uri.port}" + href
  end

  # check DAV:put-under-version-control
  def check_postcond_dav_put_under_version_control(url, creds={})
    response = @request.propfind(url, 0, :"checked-in", :"version-history", creds)
    new_version = href_elem_to_url response[:"checked-in"]
    version_history = href_elem_to_url response[:"version-history"]
    assert new_version, version_history

    # TODO: move checking equality of two urls into separate function
    vcr_body = @request.get(url, creds).body
    version_body = @request.get(new_version, creds).body
    assert_equal vcr_body, version_body

    response = @request.propfind(version_history, 0, :"root-version", :resourcetype, creds)
    root_version = href_elem_to_url response[:"root-version"]
    assert_equal new_version, root_version
    assert response[:resourcetype].match("version-history")
  end

  def test_simple_version_control
    new_file 'file', @stream

    response = @request.version_control 'file'
    assert_equal '200', response.status

    check_postcond_dav_put_under_version_control('file')


    response = @request.propfind('file', 0, :"version-history")
    version_history = href_elem_to_url response[:"version-history"]

    response = @request.delete(version_history)
    assert '204', response.status
    
    delete_file 'file'
  end

  def test_simple_checkout_checkin
    new_file 'file', @stream

    response = @request.version_control 'file'
    assert_equal '200', response.status

    response = @request.checkout 'file', 0
    assert_equal '200', response.status

    response = @request.put('file', StringIO.new("test_file"))
    assert_equal '204', response.status

    response = @request.checkin 'file', 0, 0
    assert_equal '201', response.status

    # cleanup
    response = @request.propfind('file', 0, :"version-history")
    version_history = href_elem_to_url response[:"version-history"]

    response = @request.delete(version_history)
    assert '204', response.status
    
    delete_file 'file'
  end

  def test_dav_must_not_change_existing_checked_in_out
    file = 'file'
    new_file file, @stream

    response = @request.version_control file
    assert_equal '200', response.status

    # try it again
    response = @request.version_control file
    assert_equal '200', response.status

    # checkout and try again. the checked status shouldn't change
    response = @request.checkout file, 0
    assert_equal '200', response.status

    response = @request.version_control file
    assert_equal '200', response.status

    response = @request.propfind(file, 0, :"checked-out")
    assert response[:"checked-out"]
    
    # checkin and do it again.
    response = @request.checkin file, 0, 0
    assert_equal '201', response.status

    response = @request.version_control file
    assert_equal '200', response.status

    response = @request.propfind(file, 0, :"checked-in", :"version-history")
    assert response[:"checked-in"]
    version_history = href_elem_to_url response[:"version-history"]

    delete_file 'file'

    response = @request.delete(version_history)
    assert_equal '204', response.status
  end

  def test_dav_cannot_modify_version
    file = 'file'
    new_file file, @stream

    author_prop_key = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')

    # add a dead property
    response = @request.proppatch(file, { author_prop_key => 'chetan' })
    assert !response.error?
    assert_equal '207', response.status
    assert_equal '200', response.statuses(author_prop_key)

    response = @request.version_control file
    assert_equal '200', response.status
    
    response = @request.propfind(file, 0, :"checked-in", :"version-history")
    version = href_elem_to_url response[:"checked-in"]
    version_history = href_elem_to_url response[:"version-history"]

    # try to change body and a dead property on the version
    response = @request.put(file, StringIO.new("test_file"))
    assert '412', response.status

    response = @request.proppatch(file, { author_prop_key => 'test1' })
    assert '412', response.status

    delete_file 'file'

    response = @request.delete(version_history)
    assert_equal '204', response.status
  end

  def test_dav_cannot_modify_version_controlled_property
    file = 'file'
    new_file file, @stream

    author_prop_key = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')

    # add a property
    response = @request.proppatch(file, { author_prop_key => 'chetan' })
    assert !response.error?
    assert_equal '207', response.status
    assert_equal '200', response.statuses(author_prop_key)

    response = @request.version_control file
    assert_equal '200', response.status

    # check that it's in checked-in state
    response = @request.propfind(file, 0, :"checked-in", :"version-history")
    assert response[:"checked-in"]
    version_history = href_elem_to_url response[:"version-history"]

    # try to change a dead property on checked-in vcr
    response = @request.proppatch(file, { author_prop_key => 'test1' })
    assert '412', response.status

    delete_file 'file'

    response = @request.delete(version_history)
    assert_equal '204', response.status
  end

  def test_dav_cannot_modify_protected_property
    file = 'file'
    new_file file, @stream

    checkedin_pk = RubyDav::PropKey.get('DAV:', 'checked-in')

    response = @request.version_control file
    assert_equal '200', response.status

    response = @request.proppatch(file, { checkedin_pk => 'illegalvalue' })
    # trying to change property on a checked-in vcr
    assert '409', response.status

    response = @request.checkout file, 0
    assert_equal '200', response.status

    response = @request.proppatch(file, { checkedin_pk => 'illegalvalue' })
    assert_equal '207', response.status
    # FIXME hmmm.. should this be 403 or 412?
    assert_equal '403', response.statuses(checkedin_pk)

    delete_file 'file'
  end

  def test_copy_on_vcr
    file = 'file'
    new_file file, @stream
    
    response = @request.version_control file
    assert_equal '200', response.status

    srcfile = 'srcfile'
    response = @request.put(srcfile, StringIO.new("test_file"))
    assert '201', response.status

    # try copying onto checked in vcr
    response = @request.copy(srcfile, file, RubyDav::INFINITY, true)
    assert '409', response.status

    # checkout vcr
    response = @request.checkout file, 0
    assert_equal '200', response.status

    response = @request.copy(srcfile, file, RubyDav::INFINITY, true)
    assert_equal '204', response.status

    # copy back onto srcfile and check that the versioning properties aren't copied
    response = @request.copy(file, srcfile, RubyDav::INFINITY, true)
    assert_equal '204', response.status
    
    response = @request.propfind(srcfile, 0, :"checked-out", :"version-history")
    assert_equal '404', response.statuses(:"checked-out")
    assert_equal '404', response.statuses(:"version-history")

    # delete the checked-out vcr
    delete_file file

    delete_file srcfile
  end

  def test_simple_version_tree_report
    file = 'file'
    new_file file, @stream
    
    response = @request.version_control file
    assert_equal '200', response.status
    
    checkout_put_checkin file, StringIO.new("test_file_v2")
    checkout_put_checkin file, StringIO.new("test_file_v3")

    response = @request.version_tree_report file, :"version-name", :"creator-displayname", :"successor-set"
    assert_equal '207', response.status

    # we have created three versions. assert that version-tree-report presented all of them
    assert_equal 3, response.versions.length

    #FIXME test for the response elements
    delete_file file
  end

  def test_dav_cannot_modify_version_controlled_content
    file = 'file'
    new_file file, @stream

    response = @request.version_control file
    assert_equal '200', response.status

    # check that it's in checked-in state
    response = @request.propfind(file, 0, :"checked-in", :"version-history")
    assert response[:"checked-in"]
    version_history = href_elem_to_url response[:"version-history"]

    # try to put on checked-in vcr
    response = @request.put(file, StringIO.new("test_file"))
    assert '412', response.status

    delete_file 'file'

    response = @request.delete(version_history)
    assert_equal '204', response.status
  end

end
