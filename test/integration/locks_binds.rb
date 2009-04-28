require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavLocksTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  # test scenario 1
  #
  #
  def setup_test_scenario_1
    @request.delete('dstcol')
    response = @request.mkcol('dstcol')
    assert_equal '201', response.status

    response = @request.put('dstcol/file', @stream)
    assert_equal '201', response.status

    response = @request.mkcol('dstcol/subcol')
    assert_equal '201', response.status

    @request.delete('srccol')
    response = @request.mkcol('srccol')
    assert_equal '201', response.status

    response = @request.put('srccol/file', StringIO.new("src collection file"))
    assert_equal '201', response.status
  end

  def cleanup_test_scenario_1
    response = @request.delete('dstcol')
    assert_equal '204', response.status

    response = @request.delete('srccol')
    assert response.status == '204' || response.status == '404'
  end

  def setup_test_scenario_2
    setup_test_scenario_1

    response = @request.mkcol('srccol/subcol')
    assert_equal '201', response.status

    response = @request.mkcol('srccol/subcol/subsubcol')
    assert_equal '201', response.status

    response = @request.mkcol('srccol/subcol2')
    assert_equal '201', response.status

    response = @request.bind('srccol/subcol2', 'subsubcol', 'srccol/subcol/subsubcol')
    assert_equal '201', response.status

    response = @request.mkcol('dstcol/subcol2')
    assert_equal '201', response.status
  end

  def cleanup_test_scenario_2
    cleanup_test_scenario_1
  end

  def test_unlock_via_non_lockroot_bind
    new_coll 'col'
    new_file 'col/file', StringIO.new("col_file")

    response = @request.bind('col', 'file2', 'col/file')
    assert_equal '201', response.status

    lock = lock 'col/file'
    
    response = @request.unlock('col/file2', lock.token)
    assert_equal '204', response.status

    response = @request.delete 'col'
    assert_equal '204', response.status
  end

  def test_lock_transfer_copy_overwrite_file
    setup_test_scenario_1

    # create a lock and try to remove a bind along it's lockroot
    lock = lock 'dstcol/file'

    response = @request.copy('srccol', 'dstcol', RubyDav::INFINITY, true)
    assert_equal '423', response.status

    ifhdr = { 'dstcol/file' => lock.token }
    response = @request.copy('srccol', 'dstcol', RubyDav::INFINITY, true,
                             :if => ifhdr)
    assert_equal '204', response.status

    # verify that the locks are transferred
    # TODO: implement a propfind_locks
    response = @request.put('dstcol/file', StringIO.new("doomed Test put"))
    assert_equal '423', response.status

    response = @request.put('dstcol/file', StringIO.new("Test put"),
                            :if => ifhdr)
    assert_equal '204', response.status

    response = @request.unlock('dstcol/file', lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_1
  end

  def test_lock_transfer_copy_overwrite_col
    setup_test_scenario_1
    
    response = @request.mkcol('srccol/subcol')
    assert_equal '201', response.status

    response = @request.put('srccol/subcol/file', StringIO.new("srccol_subcol_file"))
    assert_equal '201', response.status

    lock = lock 'dstcol/subcol'

    response = @request.copy('srccol', 'dstcol', RubyDav::INFINITY, true)
    assert_equal '423', response.status

    response = @request.copy('srccol', 'dstcol', RubyDav::INFINITY, true,
                             :if => { 'dstcol/subcol' => lock.token })
    assert_equal '204', response.status

    
    response = @request.delete('dstcol/subcol/file')
    assert_equal '423', response.status

    response = @request.unlock('dstcol/subcol', lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_1
  end

  def test_simple_lock_retention
    response = @request.delete('dstfile')
    response = @request.put('dstfile', @stream)
    assert_equal '201', response.status

    response = @request.delete('srcfile')
    response = @request.put('srcfile', StringIO.new("src file"))
    assert_equal '201', response.status
    
    sl1 = lock 'dstfile', :scope => :shared, :depth => 0
    ifhdr1 = { 'dstfile' => sl1.token }

    sl2 = lock 'dstfile', :scope => :shared, :depth => 0
    ifhdr2 = { 'dstfile' => sl2.token }

    response = @request.copy('srcfile', 'dstfile', 0, true,
                             :if => ifhdr1)
    assert_equal '204', response.status

    response = @request.put('dstfile', StringIO.new("dst file"))
    assert_equal '423', response.status

    response = @request.put('dstfile', StringIO.new("dst file"),
                            :if => ifhdr1)
    assert_equal '204', response.status

    response = @request.unlock('dstfile', sl1.token)
    assert_equal '204', response.status

    response = @request.put('dstfile', StringIO.new("dst file"))
    assert_equal '423', response.status

    response = @request.put('dstfile', StringIO.new("dst file"),
                            :if => ifhdr2)
    assert_equal '204', response.status

    response = @request.unlock('dstfile', sl2.token)
    assert_equal '204', response.status

    response = @request.delete('dstfile')
    assert_equal '204', response.status

    response = @request.delete('srcfile')
    assert_equal '204', response.status
  end

  def test_x_depth_inf_lock_clash_after_bind
    setup_test_scenario_2

    lock = lock 'dstcol/subcol'
    lock2 = lock 'dstcol/subcol2'

    response = @request.bind('', 'dstcol', 'srccol', :overwrite => true)
    assert_equal '423', response.status

    response = @request.bind('', 'dstcol', 'srccol',
                             :overwrite => true,
                             :if => {
                               lock.root => lock.token,
                               lock2.root => lock2.token
                             })
    
    assert_equal '409', response.status

    response = @request.unlock('dstcol/subcol', lock.token)
    assert_equal '204', response.status

    response = @request.unlock('dstcol/subcol2', lock2.token)
    assert_equal '204', response.status

    cleanup_test_scenario_2
  end

  def test_s_depth_inf_lock_after_bind
    setup_test_scenario_2

    lock = lock 'dstcol/subcol', :scope => :shared
    lock2 = lock 'dstcol/subcol2', :scope => :shared

    ifhdr = {
      lock.root => lock.token,
      lock2.root => lock2.token
    }

    response = @request.bind('', 'dstcol', 'srccol', :overwrite => true)
    assert_equal '423', response.status

    response = @request.bind('', 'dstcol', 'srccol',
                             :overwrite => true, :if => ifhdr)
    assert_equal '200', response.status

    # check that subsubcol is actually locked
    response = @request.mkcol('dstcol/subcol2/subsubcol/newcol')
    assert_equal '423', response.status

    response = @request.mkcol('dstcol/subcol2/subsubcol/newcol',
                              :if => ifhdr)
    assert_equal '201', response.status

    response = @request.delete('dstcol/subcol2/subsubcol')
    assert_equal '423', response.status

    response = @request.unlock('dstcol/subcol', lock.token)
    assert_equal '204', response.status

    response = @request.unlock('dstcol/subcol2', lock2.token)
    assert_equal '204', response.status

    cleanup_test_scenario_2
  end

  def test_rebind_in_presence_of_locks_and_bind_loops
    # See Sec 2.6 of webdav-bind-draft-19
    # home directory is the root collection
    response = @request.mkcol('CollW')
    assert_equal '201', response.status

    response = @request.mkcol('CollW/CollX')
    assert_equal '201', response.status

    response = @request.mkcol('CollW/CollY')
    assert_equal '201', response.status

    response = @request.put('CollW/CollY/y.gif', @stream)
    assert_equal '201', response.status

    response = @request.bind('CollW/CollY', 'CollZ', 'CollW')
    assert_equal '201', response.status

    lock = lock 'CollW'
    
    response = @request.rebind('CollW/CollX', 'CollA', 'CollW/CollY/CollZ')
    assert_equal '423', response.status

    response = @request.rebind('CollW/CollX', 'CollA', 'CollW/CollY/CollZ',
                               :if => lock.token)
    assert_equal '201', response.status

    # verify that the lock is still present
    response = @request.mkcol('CollW/testcol')
    assert_equal '423', response.status

    response = @request.delete('CollW', :if => lock.token)
    assert_equal '204', response.status
  end

  def test_multiple_lockroots_unbind
    setup_test_scenario_1

    response = @request.mkcol('srccol/subcol')
    assert_equal '201', response.status
    
    locks = [ lock('srccol', :scope => :shared, :depth => 0),
              lock('srccol/file', :scope => :shared, :depth => 0),
              lock('srccol/subcol', :scope => :shared, :depth => 0),
              lock('srccol', :scope => :shared, :depth => RubyDav::INFINITY) ]
    
    response = @request.unbind('', 'srccol')
    # we don't provide some locks on children and some on the collection itself. the response is sometimes
    # 423 and sometimes 207 depending on the order in which the locks are retreived from the database when checking
    assert (response.status == '423' || (response.status == '207' && response.responses.values[0].status == '423'))
    
    ifhdr = Hash.new { |h, k| h[k] = [] }
    locks[0..1].each do |l|
      ifhdr[l.root] << l.token
      response = @request.unbind('', 'srccol', :if => ifhdr)
      assert (response.status == '423' || (response.status == '207' && response.responses.values[0].status == '423'))
    end

    ifhdr[locks[2].root] << locks[2].token
    response = @request.unbind('', 'srccol', :if => ifhdr)
    # if we provide all the locks on children and miss one on the collection itself, we must get a 423
    assert_equal '423', response.status

    ifhdr[locks.last.root] << locks.last.token
    response = @request.unbind('', 'srccol', :if => ifhdr)
    assert_equal '200', response.status

    # verify the unbind
    response = @request.mkcol('srccol')
    assert_equal '201', response.status

    cleanup_test_scenario_1
  end

  def test_lock_inheritance_of_new_children_after_bind
    setup_test_scenario_1

    # lock the dstcol. we'll bind srccol into this
    lock = lock 'dstcol'

    # we'll first have a conflicting lock on srccol and verify failure
    lock_that_will_conflict = lock 'srccol'

    response = @request.bind('dstcol', 'srccol', 'srccol')
    assert_equal '423', response.status

    ifhdr = { 'dstcol' => lock.token }
    response = @request.bind('dstcol', 'srccol', 'srccol', :if => ifhdr)
    assert_equal '409', response.status

    response = @request.unlock('srccol', lock_that_will_conflict.token)
    assert_equal '204', response.status

    response = @request.bind('dstcol', 'srccol', 'srccol')
    assert_equal '423', response.status

    response = @request.bind('dstcol', 'srccol', 'srccol', :if => ifhdr)
    assert_equal '201', response.status

    # verify that dstcol locks were inherited
    response = @request.put('dstcol/srccol/file', StringIO.new("dstcol/srccol/file"))
    assert_equal '423', response.status

    response = @request.put('dstcol/srccol/file', StringIO.new("dstcol/srccol/file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    # try a put to the original uri
    response = @request.put('srccol/file', StringIO.new("srccol/file"))
    assert_equal '423', response.status

    response = @request.put('srccol/file', StringIO.new("srccol/file"),
                            :if=>ifhdr)
    assert_equal '204', response.status

    response = @request.mkcol('srccol/new_subcol')
    assert_equal '423', response.status

    response = @request.mkcol('srccol/new_subcol', :if => ifhdr)
    assert_equal '201', response.status

    response = @request.unbind('dstcol', 'srccol')
    assert_equal '423', response.status

    response = @request.unlock('dstcol', lock.token)
    assert_equal '204', response.status

    response = @request.unbind('dstcol', 'srccol')
    assert_equal '200', response.status

    cleanup_test_scenario_1
  end
  
  def test_diamond_lock_inheritance
    setup_test_scenario_2

    response = @request.put('srccol/subcol/file', StringIO.new("srccol_subcol_file"))
    assert_equal '201', response.status

    srccol_lock = lock 'srccol'
    ifhdr = { 'srccol' => srccol_lock.token }

    response = @request.bind('srccol/subcol2', 'file', 'srccol/subcol/file')
    assert_equal '423', response.status

    response = @request.bind('srccol/subcol2', 'file', 'srccol/subcol/file',
                             :if => ifhdr)
    assert_equal '201', response.status

    response = @request.unbind('srccol/subcol', 'file')
    assert_equal '423', response.status

    response = @request.unbind('srccol/subcol', 'file', :if => ifhdr)
    assert_equal '200', response.status

    response = @request.put('srccol/subcol2'+'/file', StringIO.new("srccol_subcol2_file"))
    assert_equal '423', response.status

    response = @request.put('srccol/subcol2/file', StringIO.new("srccol_subcol2_file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    # for a change, try unlocking through a child
    response = @request.unlock('srccol/subcol2', srccol_lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_2
  end

  def test_bind_to_ancestor_of_depth_inf_locked_collection_into_collection
    setup_test_scenario_1

    lock = lock 'dstcol/subcol'
    ifhdr = { 'dstcol/subcol' => lock.token }

    response = @request.bind('dstcol/subcol', 'anc', 'dstcol')
    assert_equal '423', response.status

    response = @request.bind('dstcol/subcol', 'anc', 'dstcol', :if => ifhdr)
    assert_equal '201', response.status

    response = @request.put('dstcol/file', StringIO.new("dstcol_file"))
    assert_equal '423', response.status

    response = @request.put('dstcol/file', StringIO.new("dstcol_file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    response = @request.lock 'dstcol'
    assert_equal '423', response.status

    response = @request.unbind('dstcol', 'subcol')
    assert_equal '423', response.status

    response = @request.unbind('dstcol', 'subcol', :if => ifhdr)
    assert_equal '200', response.status

    response = @request.mkcol('dstcol/subcol')
    assert_equal '201', response.status

    cleanup_test_scenario_1
  end

  def test_bind_to_shared_locked_ancestor_of_shared_depth_inf_locked_collection_into_collection
    setup_test_scenario_1

    dstcol_lock = lock 'dstcol', :scope => :shared
    ifhdr_dstcol = { 'dstcol' => dstcol_lock.token }

    subcol_lock = lock 'dstcol/subcol', :scope => :shared
    ifhdr = { 'dstcol/subcol' => subcol_lock.token }

    response = @request.bind('dstcol/subcol', 'anc', 'dstcol')
    assert_equal '423', response.status

    response = @request.bind('dstcol/subcol', 'anc', 'dstcol', :if => ifhdr)
    assert_equal '201', response.status

    response = @request.put('dstcol/file', StringIO.new("dstcol_file"))
    assert_equal '423', response.status

    response = @request.put('dstcol/file', StringIO.new("dstcol_file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    response = @request.put('dstcol/file', StringIO.new("another dstcol_file"),
                            :if => ifhdr_dstcol)

    response = @request.lock 'dstcol'
    assert_equal '423', response.status

    response = @request.unbind('dstcol', 'subcol')
    assert_equal '423', response.status

    response = @request.unbind('dstcol', 'subcol', :if => ifhdr)
    assert_equal '200', response.status

    response = @request.mkcol('dstcol/subcol')
    assert_equal '423', response.status

    response = @request.mkcol('dstcol/subcol', :if => ifhdr)
    assert_equal '412', response.status

    response = @request.mkcol('dstcol/subcol', :if => ifhdr_dstcol)
    assert_equal '201', response.status

    response = @request.unlock('dstcol', dstcol_lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_1
  end

  def test_rebind_collection_in_place_of_locked_parent
    setup_test_scenario_2

    srccol_lock = lock 'srccol'
    ifhdr = { 'srccol' => srccol_lock.token }

    response = @request.rebind('', 'srccol', 'srccol/subcol/subsubcol',
                               :if => ifhdr, :overwrite => true)
    assert_equal '200', response.status

    response = @request.put('srccol/file', StringIO.new("srccol_file"))
    assert_equal '423', response.status

    response = @request.put('srccol/file', StringIO.new("srccol_file"),
                            :if => ifhdr)
    assert_equal '201', response.status

    response = @request.unlock('srccol', srccol_lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_2
  end

  def test_lock_transfer_bind_overwrite_file
    setup_test_scenario_1

    response = @request.propfind('srccol/file', 0, :"resource-id")
    srccol_file_uuid = response[:"resource-id"]

    lock = lock 'dstcol/file'
    ifhdr = { 'dstcol/file' => lock.token }

    response = @request.bind('dstcol', "file", 'srccol/file', :overwrite => true)
    assert_equal '423', response.status

    response = @request.bind('dstcol', "file", 'srccol/file',
                             :overwrite => true, :if => ifhdr)
    assert_equal '200', response.status

    response = @request.propfind('dstcol/file', 0, :"resource-id")
    dstcol_file_uuid = response[:"resource-id"]

    assert_equal srccol_file_uuid, dstcol_file_uuid

    # check that the lock is transferred
    response = @request.put('dstcol/file', StringIO.new("dst collection file"))
    assert_equal '423', response.status

    response = @request.put('dstcol/file', StringIO.new("dst collection file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    # verify that the source file is also locked
    response = @request.put('srccol/file', StringIO.new("src collection file"))
    assert_equal '423', response.status

    response = @request.put('srccol/file', StringIO.new("src collection file"),
                            :if => ifhdr)
    assert_equal '204', response.status

    # FIXME: should deleting the srccol result in 424?
    # response = @request.delete('srccol')
    # assert_equal '424', response.status

    # unlock the resource with lockroot dstcol_file using its srccol_file uri
    response = @request.unlock('srccol/file', lock.token)
    assert_equal '204', response.status

    cleanup_test_scenario_1
  end
end
