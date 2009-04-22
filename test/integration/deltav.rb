require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavDeltavTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def href_elem_to_url prop_result
    href_element = RubyDav.xpath_first prop_result.element, 'href'
    href = RubyDav.remove_trailing_slashes(href_element.text)
    return "http://#{@uri.host}:#{@uri.port}" + href
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
    assert response[:resourcetype].inner_value.match("version-history")
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
    assert_equal '200', response[author_prop_key].status

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
    assert_equal '200', response[author_prop_key].status

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
    assert_equal '403', response[checkedin_pk].status

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
    assert_equal '404', response[:"checked-out"].status
    assert_equal '404', response[:"version-history"].status

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
    assert_equal 3, response.resources.length

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

  def test_auto_version_new_children_property
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    response = @request.propfind('testcol', 0, lb_av_new_children_propkey)
    assert_equal '207', response.status
    assert_equal '404', response[lb_av_new_children_propkey].status

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"checkout-checkin")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200', response[lb_av_new_children_propkey].status

    response = @request.propfind('testcol', 0, lb_av_new_children_propkey)
    assert_equal '207', response.status
    assert_equal '200', response[lb_av_new_children_propkey].status

    assert_xml_matches(response[lb_av_new_children_propkey].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.xmlns! :L => 'http://limebits.com/ns/1.0/'
      xml.L(:'auto-version-new-children') { xml.D :"checkout-checkin" }
    end

    delete_coll 'testcol'
  end

  def test_av_new_children_inherited_by_child_collections
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"checkout-checkin")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200', response[lb_av_new_children_propkey].status

    response = @request.mkcol 'testcol/childcol'
    assert '201', response.status

    response = @request.propfind('testcol/childcol', 0, lb_av_new_children_propkey)
    assert_equal '207', response.status
    assert_equal '200', response[lb_av_new_children_propkey].status

    assert_xml_matches(response[lb_av_new_children_propkey].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.xmlns! :L => 'http://limebits.com/ns/1.0/'
      xml.L(:'auto-version-new-children') { xml.D :"checkout-checkin" }
    end

    delete_coll 'testcol'
  end

  def test_av_new_children_version_control
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.lb(:"version-control", "xmlns:lb" => "http://limebits.com/ns/1.0/")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200',  response[lb_av_new_children_propkey].status

    new_file 'testcol/file', @stream

    check_postcond_dav_put_under_version_control('testcol/file')

    response = @request.propfind('testcol/file', 0, :"auto-version")
    assert_equal '404', response[:"auto-version"].status

    delete_coll 'testcol'
  end

  def helper_test_auto_version_checkout_checkin filename
    response = @request.propfind(filename, 0, :"checked-in")
    current_version = href_elem_to_url response[:"checked-in"]

    versions_col = File.dirname current_version
    version_num = File.basename(current_version).to_i

    response = @request.put filename, StringIO.new("testcontent")
    assert_equal '204', response.status

    response = @request.propfind(filename, 0, :"checked-in")
    new_version = href_elem_to_url response[:"checked-in"]

    assert_equal (versions_col + "/#{version_num+1}"), new_version
  end

  def test_av_new_children_checkout_checkin
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"checkout-checkin")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200', response[lb_av_new_children_propkey].status

    new_file 'testcol/file', @stream

    check_postcond_dav_put_under_version_control('testcol/file')

    response = @request.propfind('testcol/file', 0, :"auto-version")
    assert_equal '200', response[:"auto-version"].status

    assert_xml_matches(response[:"auto-version"].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D(:"auto-version") { xml.D :"checkout-checkin" }
    end

    helper_test_auto_version_checkout_checkin 'testcol/file'

    delete_coll 'testcol'
  end

  def helper_test_auto_version_checkout_unlocked_checkin filename
    response = @request.propfind(filename, 0, :"checked-in")
    current_version = href_elem_to_url response[:"checked-in"]

    versions_col = File.dirname current_version
    version_num = File.basename(current_version).to_i

    response = @request.put filename, StringIO.new("testcontent")
    assert_equal '204', response.status

    response = @request.propfind(filename, 0, :"checked-in")
    new_version = href_elem_to_url response[:"checked-in"]

    assert_equal (versions_col + "/#{version_num+1}"), new_version

    # TODO: take a lock and retry the request. check that resource is in checked-out status this time
  end

  def _test_av_new_children_checkout_unlocked_checkin
    # FIXME: make this test work
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"checkout-unlocked-checkin")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200',  response[lb_av_new_children_propkey].status

    new_file 'testcol/file', @stream

    check_postcond_dav_put_under_version_control('testcol/file')

    response = @request.propfind('testcol/file', 0, :"auto-version")
    assert_equal '200', response[:"auto-version"].status
    assert_xml_matches(response[:"auto-version"].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D(:"auto-version") { xml.D :"checkout-unlocked-checkin" }
    end

    helper_test_auto_version_checkout_unlocked_checkin 'testcol/file'

    delete_coll 'testcol'
  end

  def helper_test_auto_version_checkout

  end

  def _test_av_new_children_checkout
    # FIXME: make this test work
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"checkout")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200', response[lb_av_new_children_propkey].status

    new_file 'testcol/file', @stream

    check_postcond_dav_put_under_version_control('testcol/file')

    response = @request.propfind('testcol/file', 0, :"auto-version")
    assert_equal '200', response[:"auto-version"].status
    assert_xml_matches(response[:"auto-version"].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D(:"auto-version") { xml.D :"checkout" }
    end

    delete_coll 'testcol'
  end

  def _test_av_new_children_locked_checkout
    # FIXME: make this test work
    new_coll 'testcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')

    av_val = ::Builder::XmlMarkup.new
    av_val.D(:"locked-checkout")

    response = @request.proppatch('testcol', {lb_av_new_children_propkey => av_val})
    assert_equal '200', response[lb_av_new_children_propkey].status

    new_file 'testcol/file', @stream

    check_postcond_dav_put_under_version_control('testcol/file')

    response = @request.propfind('testcol/file', 0, :"auto-version")
    assert_equal '200', response[:"auto-version"].status
    assert_xml_matches(response[:"auto-version"].value) do |xml|
      xml.xmlns! :D => "DAV:"
      xml.D(:"auto-version") { xml.D :"locked-checkout" }
    end

    delete_coll 'testcol'
  end

  def test_copy_on_collection_containing_checked_in_vcr
    new_coll 'dstcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')
    av_val = ::Builder::XmlMarkup.new
    av_val.lb(:"version-control", "xmlns:lb" => "http://limebits.com/ns/1.0/")

    @request.proppatch('dstcol', {lb_av_new_children_propkey => av_val})
    
    new_file 'dstcol/file', @stream

    new_coll 'srccol'
    new_file('srccol/file', StringIO.new("srcfile"))
    new_file('srccol/file2', StringIO.new("srcfile2"))

    response = @request.copy 'srccol', 'dstcol', RubyDav::INFINITY, true
    assert_equal '207', response.status
    dstfile_err_resp = response.responses[@uri.path + 'dstcol/file']
    assert_equal '409', dstfile_err_resp.status

    delete_coll 'srccol'
    delete_coll 'dstcol'
  end

  def test_copy_on_collection_containing_checked_in_vcr_with_av_checkout_checkin

    new_coll 'dstcol'

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')
    av_val = ::Builder::XmlMarkup.new
    av_val.D :"checkout-checkin"

    @request.proppatch('dstcol', {lb_av_new_children_propkey => av_val})

    new_file 'dstcol/file', @stream
    check_postcond_dav_put_under_version_control('dstcol/file')

    response = @request.propfind('dstcol/file', 0, :"checked-in")
    current_version = href_elem_to_url response[:"checked-in"]
    versions_col = File.dirname current_version
    version_num = File.basename(current_version).to_i

    new_coll 'srccol'
    new_file('srccol/file', StringIO.new("srccol/file"))
    new_file('srccol/file2', StringIO.new("srccol/file2"))

    response = @request.copy 'srccol', 'dstcol', RubyDav::INFINITY, true
    assert_equal '204', response.status

    response = @request.propfind('dstcol/file', 0, :"checked-in")
    new_version = href_elem_to_url response[:"checked-in"]

    assert_equal (versions_col + "/#{version_num+1}"), new_version

    delete_coll 'srccol'
    delete_coll 'dstcol'
  end

  def test_av_new_children_inherited_and_used_at_copy_destination_for_new_children_only
    new_coll 'dstcol'
    new_file('dstcol/file2', StringIO.new("dstcol/file2"))

    lb_av_new_children_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'auto-version-new-children')
    av_val = ::Builder::XmlMarkup.new
    av_val.lb(:"version-control", "xmlns:lb" => "http://limebits.com/ns/1.0/")

    @request.proppatch('dstcol', {lb_av_new_children_propkey => av_val})

    new_coll 'srccol'
    new_file('srccol/file', StringIO.new("srccol/file"))
    new_file('srccol/file2', StringIO.new("srccol/file2"))
    new_coll 'srccol/subcol'
    new_file('srccol/subcol/file', StringIO.new("srccol/subcol/file"))

    response = @request.copy 'srccol', 'dstcol', RubyDav::INFINITY, true
    assert_equal '204', response.status

    check_postcond_dav_put_under_version_control('dstcol/file')
    check_postcond_dav_put_under_version_control('dstcol/subcol/file')

    error_raised = false
    begin
      check_postcond_dav_put_under_version_control('dstcol/file2')
    rescue
      error_raised = true
    ensure
      assert error_raised
    end
      
    response = @request.propfind('dstcol/subcol', 0, lb_av_new_children_propkey)
    assert_equal '207', response.status
    assert_equal '200', response[lb_av_new_children_propkey].status

    assert_xml_matches(response[lb_av_new_children_propkey].value) do |xml|
      xml.xmlns! :lb => "http://limebits.com/ns/1.0/"
      xml.lb(:"auto-version-new-children") { xml.lb :"version-control" }
    end

  end

end
