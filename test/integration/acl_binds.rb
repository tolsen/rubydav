require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavAclBindsTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_delete_unbind_denied
    # grant bind privilege to test user on host
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :bind)
    acl = add_ace_and_set_acl '', ace

    new_file 'foo', @stream, testcreds
    response = @request.delete('foo', testcreds)
    assert_equal '403', response.status

    #cleanup
    delete_file 'foo'
    acl.shift
    response = @request.acl('', acl)
    assert_equal '200', response.status
  end

  def test_delete_unbind_granted
    # grant unbind privilege to test user on host
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :unbind)
    acl = add_ace_and_set_acl '', ace

    new_file 'foo'
    delete_file 'foo', testcreds

    # cleanup
    acl.shift
    response = @request.acl('', acl)
    assert_equal '200', response.status
  end

  def test_bind_perms
    coll = 'bindtest'
    file = 'testfile'
    file2 = 'testfile2'

    new_coll coll
    new_file file, StringIO.new("test")
    new_file file2, StringIO.new("test2")

    
    # grant bind on coll to test
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :bind)
    acl = add_ace_and_set_acl coll, ace

    # fresh bind w/o perms
    response = @request.bind('', 'bind_wo_perm', file, testcreds)
    assert_equal '403', response.status
    response = @request.get('bind_wo_perm')
    assert_equal '404', response.status
    
    # fresh bind w/ perms
    response = @request.bind(coll, 'bind_w_perm', file, testcreds)
    assert_equal '201', response.status
    assert_content_equals "test", coll+'/bind_w_perm' 
    
    # overwriting bind w/o perms
    response = @request.bind(coll, 'bind_w_perm', file2, testcreds)
    assert_equal '403', response.status
    assert_content_equals "test", coll+'/bind_w_perm'
    
    # overwriting bind w/ perms
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :unbind)
    acl = add_ace_and_set_acl coll, ace
    response = @request.bind(coll, 'bind_w_perm', file2, testcreds)
    assert_equal '200', response.status
    assert_content_equals "test2", coll+'/bind_w_perm' 
    
    # cleanup
    delete_coll coll
    delete_file file
    delete_file file2
  end
end
