require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavLocksTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end
  
  # Create a file, lock it, unlock it and then delete it
  def test_lock_unlock
    response = @request.delete('file')

    response = @request.put('file', @stream)
    assert_equal '201', response.status

    # get an exclusive write lock
    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('file', lockinfo)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    # assert that it can't be deleted while still locked
    response = @request.delete('file')
    assert_equal '423', response.status

    response = @request.unlock('file', lockinfo.token)
    assert_equal '204', response.status

    response = @request.delete('file')
    assert_equal '204', response.status
  end

  def test_put_on_locknull
    response = @request.delete('locknull')

    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    lockinfo = response.lockinfo

    if_hdr = { 'locknull' => lockinfo.token }
    response = @request.put('locknull', StringIO.new("test"), :if => if_hdr)
    assert_equal '201', response.status

    response = @request.unlock('locknull', lockinfo.token)
    assert_equal '204', response.status

    response = @request.get('locknull')
    assert_equal '200', response.status
    assert_equal 'test', response.body

    response = @request.delete 'locknull'
    assert_equal '204', response.status
  end

  def test_locknull_mkcol
    # ensure that coll doesn't exist
    response = @request.delete('coll')

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('coll', lockinfo)
    assert_equal '200', response.status

    # repeat the above operation and assert that it fails with 423 #8.10.7
    # try lock refresh with wrong token and assert failure with 413 #8.10.7

    # store the lock token returned by the server
    lockinfo = response.lockinfo

    # check that lock-null can't be overwritten without providing locktoken
    response = @request.mkcol('coll')
    assert_equal '423', response.status

    # provide locktoken and try again
    if_hdr = { 'coll' => lockinfo.token }
    response = @request.mkcol('coll', :if => if_hdr)
    assert_equal '201', response.status

    # do a profind on the parent and check DAV:resourcetype of coll
    response = @request.propfind('coll', 0, :resourcetype)
    assert_match /collection/, response.propertyhash[RubyDav::PropKey.get("DAV:", "resourcetype")]

    # delete without locktoken
    response = @request.delete('coll')
    assert_equal '423', response.status

    response = @request.delete('coll', :if => if_hdr)
    assert_equal '204', response.status
  end

  # Create a locknull file and check that it disappears on UNLOCK
  def test_locknull_on_unlock
    # ensure that locknull file doesn't exist
    response = @request.delete('locknull')

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    # store the lock token returned by the server
    lockinfo = response.lockinfo

    response = @request.propfind_cups('', 1)
    assert_not_nil response.children['locknull']

    response = @request.unlock('locknull', lockinfo.token)
    assert_equal '204', response.status
    
    response = @request.propfind_cups('', 1)
    assert_nil response.children['locknull']
  end

  # Create a shared lock-null resource and take another shared lock it.
  # Test that the resource disappears only after both the shared locks are removed.
  def test_shared_locknull
    # ensure that locknull file doesn't exist
    response = @request.delete('locknull')

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:scope => :shared, :depth => 0)
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    # store the lock token returned by the server
    lockinfo1 = response.lockinfo

    # get another shared lock
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    lockinfo2 = response.lockinfo

    response = @request.unlock('locknull', lockinfo2.token)
    assert_equal '204', response.status

    response = @request.propfind_cups('', 1)
    assert_not_nil response.children['locknull']

    # assert that old locktoken doesn't work anymore
    response = @request.unlock('locknull', lockinfo2.token)
    assert_equal '409', response.status # Sec 9.11.1 of draft 18

    response = @request.unlock('locknull', lockinfo1.token)
    assert_equal '204', response.status
    
    response = @request.propfind_cups('', 1)
    assert_nil response.children['locknull']
  end

  def test_propfind_on_locknull
    # ensure that locknull file doesn't exist
    response = @request.delete('locknull')

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    # store the lock token returned by the server
    lockinfo = response.lockinfo

    response = @request.propfind('locknull', 0, :creationdate, :displayname, :resourcetype, :"resource-id")
    assert_equal '207', response.status
    assert response[:"resource-id"].strip.length > 0

    response = @request.propfind('', 1, :creationdate, :displayname, :resourcetype, :"resource-id")
    locknull_response = response.children['locknull']
    assert_not_nil locknull_response

    assert locknull_response[:"resource-id"].strip.length > 0

    response = @request.unlock('locknull', lockinfo.token)
    assert_equal '204', response.status
    
    response = @request.propfind_cups('', 1)
    assert_nil response.children['locknull']
  end

  def test_move_on_locknull
    # ensure that locknull file doesn't exist
    response = @request.delete('locknull')

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('locknull', lockinfo)
    assert_equal '200', response.status

    lockinfo = response.lockinfo

    response = @request.move('locknull', 'nulllock')
    assert_equal '404', response.status

    response = @request.unlock('locknull', lockinfo.token)
    assert_equal '204', response.status
    
    response = @request.propfind_cups('', 1)
    assert_nil response.children['locknull']
  end

  def test_expired_locknull
    res_name = 'locknull_for_exp'
    response = @request.delete res_name

    # create a exclusive write locked null resource
    lockinfo = RubyDav::LockInfo.new(:depth => 0, :timeout => 2)
    response = @request.lock(res_name, lockinfo)
    assert_equal '200', response.status

    # wait for the lock to expire
    sleep 4

    response = @request.propfind(res_name, 0, :displayname)
    assert_equal '404', response.status
    
    response = @request.propfind_cups('', 1)
    assert_nil response.children[res_name]
 end

  # check that lock on collection will fail if we don't have permissions on a child
  # rfc2518bis-draft-18 #rfc.section.9.10.9
  def test_multi_resource_lock_forbidden
    response = @request.delete('coll')

    response = @request.mkcol('coll')
    assert_equal '201', response.status

    response = @request.mkcol('coll/subcoll')
    assert_equal '201', response.status

    response = @request.put('coll/secret', @stream)
    assert_equal '201', response.status

    # get the acl of collection
    response = @request.propfind_acl('coll', 0)
    assert !response.error?
    acl = response.acl

    # grant test user all privileges on collection
    acl.unshift RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    response = @request.acl('coll', acl)
    assert_equal '200', response.status

    # get acl of secret file
    response = @request.propfind_acl('coll/secret', 0)
    assert !response.error?
    acl = response.acl

    # deny test user all privileges on secret file
    acl.unshift RubyDav::Ace.new(:deny, test_principal_uri, false, :all)
    response = @request.acl('coll/secret', acl)
    assert_equal '200', response.status

    # assert that test user can't PUT on secret file
    response = @request.put('coll/secret', StringIO.new("Investigate small file"), testcreds)
    assert_equal '403', response.status

    # try and get a  lock on the collection
    lockinfo = RubyDav::LockInfo.new
    response = @request.lock('coll', lockinfo, testcreds)
    # assert multi-status with 424 for req-uri and 403 for troublesome child
    assert_equal '207', response.status
    resps = response.responses
    assert_equal '424', resps.detect{|resp| (@uri.path + 'coll') == resp.url}.status
    assert_equal '403', resps.detect{|resp| (@uri.path + 'coll/secret') == resp.url}.status

    # cleanup
    response = @request.delete('coll', :depth => RubyDav::INFINITY)
    assert_equal '204', response.status
  end

  # check that lock on collection will fail with correct response if child has conflicting lock
  def test_multi_resource_lock_child_locked
    response = @request.delete('coll')

    response = @request.mkcol('coll')
    assert_equal '201', response.status

    response = @request.mkcol('coll/subcoll')
    assert_equal '201', response.status

    response = @request.put('coll/file', @stream)
    assert_equal '201', response.status

    response = @request.lock('coll/subcoll', RubyDav::LockInfo.new)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    response = @request.lock('coll', RubyDav::LockInfo.new)
    assert_equal '207', response.status
    resps = response.responses
    assert_equal '424', resps.detect{|resp| (@uri.path + 'coll') == resp.url}.status
    assert_equal '423', resps.detect{|resp| (@uri.path + 'coll/subcoll') == resp.url}.status

    response = @request.delete('coll', :depth => RubyDav::INFINITY,
                               :if => { 'coll/subcoll' => lockinfo.token })
  end

  def test_double_shared_lock
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201', response.status

    lockinfo = RubyDav::LockInfo.new(:scope => :shared, :depth => 0)
    response = @request.lock('file', lockinfo)
    assert_equal '200', response.status
    shared_lock1 = response.lockinfo

    response = @request.lock('file', lockinfo)
    assert_equal '200', response.status
    shared_lock2 = response.lockinfo

    response = @request.unlock('file', shared_lock2.token)
    assert_equal '204', response.status

    response = @request.delete('file')
    assert_equal '423', response.status

    response = @request.unlock('file', shared_lock1.token)
    assert_equal '204', response.status

    response = @request.delete('file')
    assert_equal '204', response.status
  end

  def test_move_simple_locked_file
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201', response.status

    response = @request.lock('file', RubyDav::LockInfo.new)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    response = @request.move('file', 'who-cares', false)
    assert_equal '423', response.status

    response = @request.move('file', 'who-cares', false, :if => { 'file' => lockinfo.token })
    assert_equal '201', response.status

    # cleanup
    response = @request.delete('file')
    assert_equal '404', response.status

    response = @request.delete('who-cares')
    assert_equal '204', response.status
  end

  def test_copy_on_medium_whose_parent_has_depth0_lock
    col = 'col'
    response = @request.delete(col)
    response = @request.mkcol(col)
    assert_equal '201', response.status

    col_file = col + '/file'
    response = @request.put(col_file, @stream)
    assert_equal '201', response.status

    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock(col, lockinfo)
    assert_equal '200', response.status
    lockinfo = response.lockinfo
    assert_equal "0", lockinfo.depth

    response = @request.put(col_file, StringIO.new("Should succeed"))
    assert_equal '204', response.status

    file = 'file'
    response = @request.put(file, StringIO.new("file to copy"))
    assert_equal '201', response.status

    response = @request.copy(file, col_file, 0, true)
    assert_equal '204', response.status

    # cleanup using unbind for a change
    response = @request.unbind('', "col")
    assert_equal '423', response.status

    response = @request.unbind('', "col", :if => { col => lockinfo.token })
    assert_equal '200', response.status

    response = @request.unbind('', "file")
    assert_equal '200', response.status
  end
  
  # WebDAV book (L. Dusseault) pp. 186-87 8.4.3
  def test_delete_if_etag_and_lock
    lock_coll = 'httplock'
    file = lock_coll + '/a'

    new_coll lock_coll

    response = @request.put(file, StringIO.new("hello"))
    assert_equal '201', response.status
    orig_etag = response.headers['etag'][0]

    lockinfo = RubyDav::LockInfo.new(:depth=>0)
    response = @request.lock(file, lockinfo)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    response = @request.put(file, StringIO.new("world"), :if => { file => lockinfo.token })
    assert_equal '204', response.status
    new_etag = response.headers['etag'][0]

    response = @request.delete(file, :if => [orig_etag, lockinfo.token])
    assert_equal '412', response.status
    
    response = @request.get(file)
    assert_equal '200', response.status
    
    response = @request.delete(file, :if => [new_etag, lockinfo.token])
    assert_equal '204', response.status
     
    response = @request.get(file)
    assert_equal '404', response.status 
    
    # cleanup
    response = @request.delete(lock_coll)
    assert_equal '204', response.status
  end

  def test_delete_if_backed_up
    new_coll 'httplock'
    new_file 'httplock/b'
    
    response = @request.copy('httplock/b', 'httplock/b-backup', 0, true)
    assert_equal '201', response.status

    response = @request.copy('httplock/b', 'httplock/b1', 0, true)
    assert_equal '201', response.status

    response = @request.put('httplock/b', StringIO.new('hello'))
    assert_equal '204', response.status

    response = @request.copy('httplock/b', 'httplock/b-backup2', 0, true)
    assert_equal '201', response.status

    b_backup_etag = get_etag('httplock/b-backup')
    b_backup2_etag = get_etag('httplock/b-backup2')

    if_hdr = [[b_backup_etag], [b_backup2_etag]]
    response = @request.delete('httplock/b', :if => if_hdr)
    assert_equal '204', response.status

    response = @request.get('httplock/b')
    assert_equal '404', response.status

    response = @request.delete('httplock/b1', :if => if_hdr)
    assert_equal '204', response.status

    response = @request.get('httplock/b1')
    assert_equal '404', response.status
    
    # cleanup
    delete_coll 'httplock'
  end
  
  # WebDAV book (L. Dusseault) pp. 188-90 8.4.5 (Listing 8-8)
  def test_move_under_single_lock
    setup_hr

    lockinfo = RubyDav::LockInfo.new(:depth => RubyDav::INFINITY)
    response = @request.lock('httplock/hr', lockinfo)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    response = @request.move('httplock/hr/recruiting/resumes', 'httplock/hr/archives/resumes')
    assert_equal '423', response.status
    assert_exists 'httplock/hr/recruiting/resumes/'
    assert_does_not_exist 'httplock/hr/archives/resumes/'

    if_hdr = lockinfo.token
    response = @request.move('httplock/hr/recruiting/resumes', 'httplock/hr/archives/resumes', false, :if => if_hdr)
    assert_equal '201', response.status
    assert_does_not_exist 'httplock/hr/recruiting/resumes/'
    assert_exists 'httplock/hr/archives/resumes/'

    # cleanup
    response = @request.unlock('httplock/hr', lockinfo.token)
    assert_equal '204', response.status
    delete_coll('httplock')
  end

  # WebDAV book (L. Dusseault) pp. 188-90 8.4.5 (Listing 8-9)
  def test_move_between_locks
    setup_hr
    new_coll 'httplock/hr/archives/resumes'

    lockinfo = RubyDav::LockInfo.new(:depth => RubyDav::INFINITY)
    response = @request.lock('httplock/hr/recruiting/resumes', lockinfo)
    assert_equal '200', response.status
    resumes_locktoken = response.lockinfo.token
    response = @request.lock('httplock/hr/archives', lockinfo)
    assert_equal '200', response.status
    archives_locktoken = response.lockinfo.token

    assert_hr_move_response '423'
    assert_hr_move_response '423', resumes_locktoken 
    assert_hr_move_response '412', archives_locktoken
    assert_hr_move_response '412', [resumes_locktoken, archives_locktoken]
    assert_hr_move_response '201', [[resumes_locktoken], [archives_locktoken]]

    # cleanup
    response = @request.unlock('httplock/hr/recruiting/resumes', resumes_locktoken)
    assert_equal '204', response.status
    response = @request.unlock('httplock/hr/archives', archives_locktoken)
    assert_equal '204', response.status
    delete_coll 'httplock'
  end
  
  # WebDAV book (L. Dusseault) pp. 190-91 8.4.6 (Listing 8-10)
  def test_move_between_locks_tagged
    setup_hr
    new_coll('httplock/hr/archives/resumes')

    lockinfo = RubyDav::LockInfo.new(:depth => RubyDav::INFINITY)
    response = @request.lock('httplock/hr/recruiting/resumes', lockinfo)
    assert_equal '200', response.status
    resumes_locktoken = response.lockinfo.token
    response = @request.lock('httplock/hr/archives', lockinfo)
    assert_equal '200', response.status
    archives_locktoken = response.lockinfo.token

    bad_if = {
                'httplock/hr/recruiting/resumes/harry' => archives_locktoken,
                'httplock/hr/archives/resumes' => resumes_locktoken
    }

    assert_hr_move_response '412', bad_if

    good_if = {
                'httplock/hr/recruiting/resumes/harry' => resumes_locktoken,
                'httplock/hr/archives/resumes' => archives_locktoken
    }

    assert_hr_move_response '201', good_if

    # cleanup
    response = @request.unlock('httplock/hr/recruiting/resumes', resumes_locktoken)
    assert_equal '204', response.status
    response = @request.unlock('httplock/hr/archives', archives_locktoken)
    assert_equal '204', response.status
    delete_coll 'httplock'
  end
  
  # WebDAV book (L. Dusseault) pp. 191-92 8.4.6 (Listing 8-11)
  def test_delete_with_child_locked
    setup_hr
    dicks_resume = 'httplock/hr/recruiting/resumes/dick'

    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock(dicks_resume, lockinfo)
    assert_equal '200', response.status
    dicks_locktoken = response.lockinfo.token

    response = @request.delete('httplock/hr/recruiting/resumes')
    assert_equal '207', response.status
    # TODO: check that response body contains a 423 for dicks_resume

    response = @request.get(dicks_resume)
    assert_equal '200', response.status

    response = @request.delete('httplock/hr/recruiting/resumes', :if => { dicks_resume => dicks_locktoken })
    assert_equal '204', response.status

    response = @request.get(dicks_resume)
    assert_equal '404', response.status

    # cleanup
    delete_coll('httplock')
  end
  
  # WebDAV book (L. Dusseault) pp. 192-93 8.4.7 (Listing 8-12)
  def test_put_too_many_locktokens_given
    new_coll 'httplock'
    new_file 'httplock/a', StringIO.new("hello")
    new_file 'httplock/b', StringIO.new("world")

    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('httplock/b', lockinfo)
    assert_equal '200', response.status
    b_locktoken = response.lockinfo.token

    response = @request.lock('httplock/a', lockinfo)
    assert_equal '200', response.status
    a_locktoken = response.lockinfo.token

    response = @request.put('httplock/a', StringIO.new('hello'), :if => [a_locktoken, b_locktoken])
    assert_equal '412', response.status
    
    response = @request.put('httplock/a', StringIO.new('hello'), { :if => [a_locktoken, b_locktoken], :strict_if => false } )
    assert_equal '204', response.status 

    # cleanup
    response = @request.unlock('httplock/a', a_locktoken)
    assert_equal '204', response.status
    response = @request.unlock('httplock/b', b_locktoken)
    assert_equal '204', response.status
    delete_coll('httplock')
  end 
 
  # WebDAV book (L. Dusseault) p. 195 8.4.12 (Listing 8-13)
  def test_put_new_resource_locked_collection_zero_depth
    setup_hr

    lockinfo = RubyDav::LockInfo.new(:depth => 0)
    response = @request.lock('httplock/hr/recruiting/resumes', lockinfo)
    assert_equal '200', response.status
    resumes_locktoken = response.lockinfo.token

    response = @request.put('httplock/hr/recruiting/resumes/ldusseault.txt', StringIO.new("lisa resume"), :if_none_match => '*')
    assert_equal '423', response.status

    response = @request.put('httplock/hr/recruiting/resumes/ldusseault.txt', StringIO.new("lisa resume"), { :if_none_match => '*', :if => { 'httplock/hr/recruiting/resumes/' => resumes_locktoken } })
    assert_equal '201', response.status

    response = @request.put('httplock/hr/recruiting/resumes/ldusseault.txt', StringIO.new("hello"))
    assert_equal '204', response.status

    # cleanup
    response = @request.unlock('httplock/hr/recruiting/resumes/', resumes_locktoken)
    assert_equal '204', response.status
    delete_coll 'httplock'
  end
   
  def setup_hr    
    new_coll 'httplock'
    new_coll 'httplock/hr'
    new_coll 'httplock/hr/recruiting'
    new_coll 'httplock/hr/recruiting/resumes'
    new_coll 'httplock/hr/archives'

    new_file 'httplock/hr/recruiting/resumes/tom', StringIO.new('genius')
    new_file 'httplock/hr/recruiting/resumes/dick', StringIO.new('one of a kind')
    new_file 'httplock/hr/recruiting/resumes/harry', StringIO.new('moron')
  end

  def assert_hr_move_response exp_response, if_hdr=nil
    opts = {}
    opts = { :if => if_hdr } unless if_hdr.nil?

    response = @request.move('httplock/hr/recruiting/resumes/tom', 'httplock/hr/archives/resumes/tom', false, opts)
    assert_equal exp_response, response.status

    success = ((response.status =~ /^2/) == 0)
    response = @request.get('httplock/hr/recruiting/resumes/tom')
    src_exists = response.status == '200'
    response = @request.get('httplock/hr/archives/resumes/tom')
    dst_exists = response.status == '200'

    assert success ^ src_exists
    assert success ^ !dst_exists
  end

  def get_etag(uri)
    response = @request.get(uri)
    response.headers['etag'][0]
  end
end
