require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavAclLocksTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_acl_props_locknull
    lknull_res = "lknull1"
    active_lock = locknull_setup lknull_res

    acl_props = [ "owner", "group", "supported-privilege-set", "current-user-privilege-set", "acl", "acl-restrictions", "inherited-acl-set", "principal-collection-set" ]

    # this maybe done in a single propfind.
    acl_props.each do |prop|
      propkey = RubyDav::PropKey.get('DAV:', prop)
      response = @request.propfind(lknull_res, 0, propkey)
      assert_equal '207', response.status
      assert_equal '404', response[propkey].status
    end

    # cleanup
    response = @request.unlock(lknull_res, active_lock.token)
  end

  def test_acl_locknull
    lknull_res = "lknull2"
    lock = locknull_setup lknull_res

    response = @request.acl(lknull_res, RubyDav::Acl.new)
    assert_equal '404', response.status

    # cleanup
    response = @request.unlock(lknull_res, lock.token)
  end

  def test_locknull_requires_bind
    lknl_file = 'testcol/lknull'

    response = @request.mkcol('testcol')
    assert_equal '201', response.status

    response = @request.lock(lknl_file, :depth => 0, :username => nil)
    assert_equal '401', response.status

    ace = RubyDav::Ace.new(:grant, :unauthenticated, false, :bind)
    add_ace_and_set_acl 'testcol', ace
    
    lock = lock lknl_file, :depth => 0, :username => nil

    # the lock token provided is actually owned by the principal DAV:unauthenticated. hence the 423
    response = @request.put(lknl_file, StringIO.new("test"), :if => {lknl_file => lock.token})
    assert_equal '423', response.status

    response = @request.unlock(lknl_file, lock.token, :username => nil)
    assert_equal '204', response.status

    response = @request.delete(lknl_file)
    assert_equal '404', response.status

    response = @request.delete('testcol')
    assert_equal '204', response.status
  end

  def locknull_setup(lknull_res)
    # ensure lknull doesn't exist
    response = @request.delete(lknull_res)
    response = @request.get(lknull_res)
    assert_equal '404', response.status

    # create a new lknull resource
    return lock lknull_res, :depth => 0
  end

  def test_update_locked_res_privileges
    lockfile = 'lockfile'
    new_file lockfile
    lock = lock lockfile

    # grant all on lockfile to test
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    add_ace_and_set_acl lockfile, ace

    ifhdr = { lockfile => lock.token }

    # try PUT on lockfile using 'test' user ( not the lockowner), 
    # without supplying locktoken
    response = @request.put(lockfile, StringIO.new("no_owner_no_token"), testcreds)
    assert_equal '423', response.status
    assert_content_equals @filebody, lockfile

    # try PUT on lockfile using 'test' user ( not the lockowner), 
    # & also supply the locktoken
    response = @request.put(lockfile, StringIO.new("no_owner_w_token"), testcreds.merge({:if => ifhdr}))
    assert_equal '423', response.status
    assert_content_equals @filebody, lockfile


    # try PUT on lockfile using the lockowner, without supplying locktoken
    response = @request.put(lockfile, StringIO.new("owner_no_token"))
    assert_equal '423', response.status
    assert_content_equals @filebody, lockfile


    # try PUT on lockfile using the lockowner, & also supply correct locktoken
    response = @request.put(lockfile, StringIO.new("owner_w_token"), :if => ifhdr)
    assert_equal '204', response.status
    assert_content_equals "owner_w_token", lockfile

    # cleanup
    response = @request.unlock(lockfile, lock.token)
    delete_file lockfile
  end

  def test_acl_unlock_privilege
    lockfile = 'lockfile'
    new_file lockfile
    lock = lock lockfile

    # grant unlock on lockfile to 'test'
    grant_unlock = RubyDav::Ace.new(:grant, test_principal_uri, false, :unlock)
    add_ace_and_set_acl lockfile, grant_unlock

    # try to unlock lockfile w 'test' user, w locktoken
    response = @request.unlock(lockfile, lock.token, testcreds)
    assert_equal '204', response.status

    # now, delete lockfile wo locktoken
    delete_file lockfile
  end
end
