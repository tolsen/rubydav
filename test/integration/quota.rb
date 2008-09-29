require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class WebDavQuotaTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_quota_props_protected
    testfile = 'file'
    new_file testfile

    response = @request.proppatch(testfile, {quota_available_bytes_pkey => '1000'})
    assert_equal '207', response.status
    assert_equal '403', response.statuses(quota_available_bytes_pkey)
    assert_dav_error response.dav_errors(quota_available_bytes_pkey), "cannot-modify-protected-property"

    delete_file testfile
  end

  def test_quota_preconditions
    quota_available = quota_available_bytes testhome, testcreds

    # ensure that bigfile is big enough to exceed quota
    bigfilesize = quota_available * 2
    resize_file @bigfilepath, bigfilesize

    @bigfile = File.read @bigfilepath
    @bigstream = StringIO.new @bigfile

    if quota_available == quota_available_bytes(testhome, testcreds)
      # now, try to put bigfile and test for quota-not-exceeded precondition
      response = @request.put(testhome + '/bigfile', @bigstream, testcreds)
      assert_equal '507', response.status
      assert_dav_error response.dav_error, "quota-not-exceeded"
    end
    delete_file testhome + '/bigfile', testcreds
  end

  def test_quota_put
    orig_quota_available = quota_available_bytes testhome, testcreds

    # PUT new file
    testfile = testhome + '/quotatest'
    new_file testfile, @stream, testcreds

    current_quota_available = quota_available_bytes testhome, testcreds
    assert (current_quota_available = orig_quota_available - @filesize)

    # PUT overwriting existing file
    # using bigfile with size in between current_quota & orig_quota
    # the PUT should succeed, since this is an overwriting PUT.
    delta = (orig_quota_available - current_quota_available)/2
    bigfilesize = orig_quota_available - delta
    put_file_w_size testfile, bigfilesize, testcreds

    current_quota_available = quota_available_bytes testhome, testcreds
    # cannot assert this due to garbage collector
    # assert_equal delta, current_quota_available

    # cleanup
    delete_file testfile, testcreds
  end

  def test_quota_copy
    srccoll = testhome + '/quotasrc'
    dstcoll = testhome + '/quotadst'
    srcfile = srccoll + '/file'

    new_coll srccoll, testcreds
    new_file srcfile, @stream, testcreds

    # fresh COPY
    response = @request.copy(srccoll, dstcoll, RubyDav::INFINITY, true, testcreds)
    assert_equal '201', response.status
    assert_equal 2*@filesize, quota_used_bytes(testhome, testcreds)

    bigfilesize = 2*@filesize
    put_file_w_size srcfile, bigfilesize, testcreds

    # overwriting COPY
    response = @request.copy(srccoll, dstcoll, RubyDav::INFINITY, true, testcreds)
    assert_equal '204', response.status
    assert_equal 4*@filesize, quota_used_bytes(testhome, testcreds)

    # cleanup
    delete_coll srccoll, testcreds
    delete_coll dstcoll, testcreds
  end

  def test_quota_move
    srcfile = 'srcfile'
    dstfile = 'dstfile'

    new_file srcfile

    quota_used_1 = quota_used_bytes

    # MOVE to a fresh destination, quota_used should remain unchanged
    response = @request.move(srcfile, dstfile, true)
    assert_equal '201', response.status
    assert_equal quota_used_1, quota_used_bytes

    # overwriting MOVE
    # first re-create srcfile
    response = @request.copy(dstfile, srcfile, 0, true)
    assert_equal '201', response.status

    response = @request.move(srcfile, dstfile, true)
    assert_equal '204', response.status
    # we can't make this assertion due to the garbage collector
    # assert_equal quota_used_1, quota_used_bytes

    # cleanup
    delete_file dstfile
  end

  def test_quota_delete
    testcoll = 'coll'
    testfile = testcoll + '/file'
    testfile2 = testcoll + '/file2'

    quota_used_1 = quota_used_bytes
    new_coll testcoll
    new_file testfile
    quota_used_2 = quota_used_bytes

    response = @request.copy(testfile, testfile2, 0, true)
    assert_equal '201', response.status

    # DELETE file
    delete_file testfile
    assert_equal quota_used_2, quota_used_bytes

    # DELETE collection
    delete_coll testcoll
    assert_equal quota_used_1, quota_used_bytes
  end

  def quota_available_bytes(path, creds)
    response = @request.propfind(path, 0, quota_available_bytes_pkey, creds)
    assert_equal '207', response.status
    response.propertyhash[quota_available_bytes_pkey].to_i
  end

  def quota_used_bytes(path=@host, creds={})
    response = @request.propfind(path, 0, quota_used_bytes_pkey, creds)
    assert_equal '207', response.status
    response.propertyhash[quota_used_bytes_pkey].to_i
  end

  def quota_available_bytes_pkey
    RubyDav::PropKey.get('DAV:', 'quota-available-bytes')
  end

  def quota_used_bytes_pkey
    RubyDav::PropKey.get('DAV:', 'quota-used-bytes')
  end
end
