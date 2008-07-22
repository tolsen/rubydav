require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavAclCopyMoveTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_acl_inheritance_move
    privatecol = 'private'
    publiccol = 'public'

    new_coll privatecol
    new_coll publiccol

    # grant all on publiccol to all
    grant_all = RubyDav::Ace.new(:grant, :all, false, :all)
    add_ace_and_set_acl publiccol, grant_all

    new_coll 'public/coll'
    new_file 'public/coll/file'

    # ensure that 'test' can access 'file'
    response = @request.get('public/coll/file', testcreds)
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    # move 'coll' to privatecoll
    response = move_coll 'public/coll', 'private/coll'
    assert_equal '201', response.status

    # 'test' should not be able to access 'file' now
    response = @request.get('private/coll/file', testcreds)
    assert_equal '403', response.status

    # cleanup
    delete_coll privatecol
    delete_coll publiccol
  end

  def test_acl_new_copy
    testfile = 'file'
    testcopy = 'copy'
    new_file testfile
    original_acl = get_acl testfile

    # add something to the default ace
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    modified_acl = add_ace_and_set_acl testfile, ace

    # now, copy the file
    response = @request.copy(testfile, testcopy, 0, true)
    assert_equal '201', response.status

    copy_acl = get_acl testcopy

    # The DAV:acl property on the resource at the destination of a COPY 
    # MUST be the same as if the resource was created by 
    # an individual resource creation request (e.g., MKCOL, PUT).
    # ensure that copy_acl is same as original acl.
    assert_equal original_acl, copy_acl

    # cleanup
    delete_file testfile
    delete_file testcopy
  end

  def test_child_read_copy
    src = 'src'
    publiccol = src + '/public'
    privatecol = src +'/private'

    new_coll src
    new_coll publiccol
    new_coll privatecol

    # grant read on src to 'test'
    grant_read = RubyDav::Ace.new(:grant, test_principal_uri, false, :read)
    add_ace_and_set_acl src, grant_read

    # deny read on private to 'test'
    deny_read = RubyDav::Ace.new(:deny, test_principal_uri, false, :read)
    add_ace_and_set_acl privatecol, deny_read

    response = @request.delete(testhome+'/dest', testcreds)

    # now, copy src to test's home
    response = @request.copy(src, testhome+'/dest', RubyDav::INFINITY, true, testcreds)
    assert_equal '201', response.status

    # ensure that privatecol was not copied
    response = @request.get(testhome+'/dest/private', testcreds)
    assert_equal '404', response.status

    # and, publiccol was copied
    response = @request.get(testhome+'/dest/public/', testcreds)
    assert_equal '200', response.status

    # cleanup
    delete_coll src
    delete_coll testhome+'/dest', testcreds
  end

  def get_resource_id url, creds={}
    response = @request.propfind(url, 0, :"resource-id", creds)
    assert !response.error?
    response[:"resource-id"]
  end

  def test_copy_which_leads_to_dst_resource_id_change_should_fail_if_no_bind_unbind_privs_on_dst_parent
    srcfile = 'srcfile'
    new_file srcfile
    test_dst = testhome + '/dst'

    new_coll test_dst, testcreds
    
    dst_coll_res_id = get_resource_id test_dst, testcreds

    grant_all = RubyDav::Ace.new(:grant, get_principal_uri(@creds[:username]), false, :all)
    add_ace_and_set_acl test_dst, grant_all, testcreds

    response = @request.copy(srcfile, test_dst)
    if response.status == '204' 
      new_dst_res_id = get_resource_id test_dst
      assert_equal new_dst_res_id, dst_coll_res_id
    else
      assert_equal '403', response.status
    end

    delete_coll test_dst, testcreds
    delete_file srcfile
  end

end
