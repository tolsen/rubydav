require 'test/unit'
require 'test/integration/webdavtestsetup'
require 'thwait'
require 'time'

class WebDavBasicTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end
  
  def test_put_get
    50.times do
      response = @request.put('file', StringIO.new("test_file"))
      assert_equal '201', response.status

      response = @request.get('file')
      assert_equal '200', response.status
      assert_equal "test_file", response.body
      
      response = @request.delete('file')
      assert_equal '204', response.status

      response = @request.get('file')
      assert_equal '404', response.status
    end
  end
  
  def test_mkcol
    response = @request.mkcol('collection')
    
    response = @request.put('collection/file', @stream)
    response = @request.get('collection/file')
    assert_equal '200', response.status
    assert_equal @filebody, response.body
    response = @request.delete('collection')
    
    response = @request.get('collection/file')
    assert_equal '404', response.status
  end

  def test_escape_characters
    # test escaping of characters
    response = @request.put("fi'le", StringIO.new("test_escape_characters"))
    assert_equal '201', response.status
    assert_content_equals "test_escape_characters", "fi'le"

    # test percent encoded characters
    response = @request.put("fi%27le2", StringIO.new("test_escape_characters"))
    assert_equal '201', response.status
    assert_content_equals "test_escape_characters", "fi%27le2"

    # cleanup
    delete_file "fi'le"
    delete_file "fi%27le2"
  end
  
  def test_copy
    response = @request.put('file1', @stream)
    assert_equal '201',response.status
    
    response = @request.copy('file1', 'file2', RubyDav::INFINITY, true)
    assert_equal '201',response.status
    
    response = @request.get('file2')
    assert_equal '200', response.status
    assert_equal @filebody, response.body 
    
    response = @request.delete('file1')
    response = @request.delete('file2')
    response = @request.get('file1')
    assert_equal '404', response.status
    response = @request.get('file2')
    assert_equal '404', response.status
  end
  
  def test_move
    response = @request.put('file1', @stream)
    assert_equal '201',response.status
    
    response = @request.move('file1', 'file2', true)
    assert_equal '201',response.status
    
    response = @request.get('file2')
    assert_equal @filebody, response.body 
    
    response = @request.delete('file2')
    response = @request.get('file1')
    assert_equal '404', response.status
    response = @request.get('file2')
    assert_equal '404', response.status
  end
  
  def test_lost_update
    
    response1 = nil
    response2 = nil

    bigfilesize = 100000000     # 100M
    resize_file @bigfilepath, bigfilesize

    @bigfile = File.read @bigfilepath
    @bigstream = StringIO.new @bigfile

    quota_used_bytes = RubyDav::PropKey.get('DAV:', 'quota-used-bytes')

    propfind_response = @request.propfind('',0, quota_used_bytes)

    # ensure that propfind was successful
    assert_equal '207', propfind_response.status
    
    initial_used_quota = propfind_response.propertyhash[quota_used_bytes].to_i

    session1 = Thread.new() do
      response1 = @request.put('bigfile', @bigstream)
    end

    session2 = Thread.new() do
      response2 = RubyDav::Request.put('bigfile', @stream, @creds.merge(:base_url => @host))
    end

    ThreadsWait.all_waits(session1, session2)

    get_response = @request.get('bigfile')

    # ensure we can get the resource
    assert_equal('200', get_response.status,
                 "could not fetch resource: #{get_response.status}. response1: #{response1.status}. response2: #{response2.status}")
    gotbody = get_response.body

    propfind_response = @request.propfind('bigfile',0, :allprop)

    # ensure that propfind was successful
    assert_equal '207', propfind_response.status

    # get the filesize
    gotsize = propfind_response.propertyhash[RubyDav::PropKey.get('DAV:', 'getcontentlength')].to_i

    propfind_response = @request.propfind('',0, quota_used_bytes)

    # ensure that propfind was successful
    assert_equal '207', propfind_response.status
    
    delta_quota = propfind_response.propertyhash[quota_used_bytes].to_i - initial_used_quota



    # Review with Paritosh: response1 is often 507 for me
    # -Tim

    if response1.status == '201'
      
      # both PUTs cannot succeed with 201
      assert_not_equal '201', response2.status
      if response2.status == '204'
        
        # second PUT also succeeded.
        # GET should give @filebody
        expbody = @filebody
        expsize = @filesize
      else
        
        # second PUT failed
        # GET should give @bigfile
        expbody = @bigfile
        expsize = bigfilesize
      end
    else
      
      # second PUT must've succeeded with 201
      assert_equal '201', response2.status

      if response1.status == '204'

        # GET should give @bigfile
        expbody = @bigfile
        expsize = bigfilesize
      else

        # first PUT failed
        # GET should give @filebody
        expbody = @filebody
        expsize = @filesize
      end
    end
    
    # ensure consistency
    assert_equal expbody, gotbody
    assert_equal expsize, gotsize
    assert_equal expsize, delta_quota

    # cleanup
    response = @request.delete('bigfile')
  end

  def test_put_unmodified
    response = @request.put('foo', StringIO.new("test1")) 
    last_modified = response.headers['last-modified'][0]

    response = @request.put('foo', StringIO.new("test2"), 
                            :if_unmodified_since => last_modified)
    
    assert_equal '204', response.status
    assert_content_equals "test2", 'foo'
    
    # cleanup
    response = @request.delete('foo')
  end

  def test_put_modified
    response = @request.put('foo', StringIO.new("test1")) 
    
    unmodified_since = (Time.httpdate(response.headers['last-modified'][0])-1).httpdate
    response = @request.put('foo', StringIO.new("test2"),
                            :if_unmodified_since => unmodified_since)
    assert_equal '412', response.status
    assert_content_equals "test1", 'foo'
    
    # cleanup
    response = @request.delete('foo')
  end

  def test_delete_no_etag
    new_file 'test', StringIO.new("test")
    response = @request.delete('test')

    # verify that no ETag header is sent for DELETE responses 
    assert_nil response.headers['etag']

    # cleanup
    delete_file 'test'
  end

  def test_put_match
    # IF-MATCH * with nothing there fails
    response = @request.put('foo', StringIO.new("test1"), :if_match => '*')
    assert_equal '412', response.status

    response = @request.get('foo')
    assert_equal '404', response.status

    # IF-NONE-MATCH * with nothing there succeeds
    response = @request.put('foo', StringIO.new("test2"), :if_none_match => '*')
    assert_equal '201', response.status
    assert_content_equals "test2", 'foo'

    # IF-NONE-MATCH * with something there fails
    response = @request.put('foo', StringIO.new("test3"), :if_none_match => '*')
    assert_equal '412', response.status
    assert_content_equals "test2", 'foo'

    # IF-MATCH * with something there succeeds
    response = @request.put('foo', StringIO.new("test4"), :if_match => '*')
    assert_equal '204', response.status
    assert_content_equals "test4", 'foo'

    # IF-MATCH with same etag succeeds
    etag1 = response.headers['etag'][0]
    response = @request.put('foo', StringIO.new("test5"), :if_match => etag1)
    assert_equal '204', response.status
    assert_content_equals "test5", 'foo'

    # IF-MATCH with different etag fails
    response = @request.put('foo', StringIO.new("test6"), :if_match => etag1)
    assert_equal '412', response.status
    assert_content_equals "test5", 'foo'

    ensure
    delete_file 'foo'
  end

  def test_etag_match_gzip

    # create a new file
    response = @request.put('foo', StringIO.new("test1"))
    assert_equal '201', response.status

    # get the gzip'ed entity & corresponding etag
    response = @request.get('foo', :accept_encoding => "gzip")
    assert_equal '200', response.status
    etag = response.headers['etag'][0]

    # check positive if_none_match etag matching with the etag for the gzip'ed entity
    response = @request.get('foo', :if_none_match => etag)
    assert_equal '304', response.status

    # check positive if_match etag matching with the etag for the gzip'ed entity
    response = @request.put('foo', StringIO.new("test2"), :if_match => etag)
    assert_equal '204', response.status

    # check negative if_none_match etag matching with the etag for the gzip'ed entity
    response = @request.get('foo', :if_none_match => etag)
    assert_equal '200', response.status

    # check negative if_match etag matching with the etag for the gzip'ed entity
    response = @request.put('foo', StringIO.new("test3"), :if_match => etag)
    assert_equal '412', response.status

    ensure
    delete_file 'foo'
  end

  def test_delete_unmodified
    response = @request.put('foo', StringIO.new('test'))
    assert_equal '201', response.status

    last_modified = response.headers['last-modified'][0]

    response = @request.delete('foo', :if_unmodified_since => last_modified)
    assert_equal '204', response.status

    response = @request.get('foo')
    assert_equal '404', response.status
  end

  def test_delete_modified
    response = @request.put('foo', StringIO.new("test1")) 
    
    unmodified_since = (Time.httpdate(response.headers['last-modified'][0])-1).httpdate
    response = @request.delete('foo', :if_unmodified_since => unmodified_since)
    assert_equal '412', response.status
    assert_content_equals "test1", 'foo'
    
    # cleanup
    response = @request.delete('foo')
  end

  def test_delete_match
    response = @request.put('foo', StringIO.new('test1'))
    assert_equal '201', response.status
    etag1 = response.headers['etag'][0]
 
    response = @request.put('foo', StringIO.new('test2'))
    assert_equal '204', response.status
    etag2 = response.headers['etag'][0]

    response = @request.delete('foo', :if_match => etag1)
    assert_equal '412', response.status
    assert_content_equals 'test2', 'foo'

    response = @request.delete('foo', :if_match => etag2)
    assert_equal '204', response.status
   
    response = @request.get('foo')
    assert_equal '404', response.status
  end

  def test_put_get_same_etag
    response = @request.put('foo', StringIO.new('test1'))
    assert_equal '201', response.status
    put_etag = response.headers['etag'][0]

    response = @request.get('foo')
    get_etag = response.headers['etag'][0]

    assert_equal put_etag, get_etag

    #cleanup
    @request.delete('foo')
  end

  def test_get_unmodified
    response = @request.put('foo', StringIO.new('test'))
    assert_equal '201', response.status

    last_modified = response.headers['last-modified'][0]

    sleep 3

    response = @request.get('foo', :if_modified_since => last_modified)
    assert_equal '304', response.status

    #cleanup
    response = @request.delete('foo')
  end

  def test_get_modified
    response = @request.put('foo', StringIO.new("test1")) 
    
    modified_since = (Time.httpdate(response.headers['last-modified'][0])-1).httpdate
    response = @request.get('foo', :if_modified_since => modified_since)
    assert_equal '200', response.status
    assert_content_equals "test1", 'foo'
    
    # cleanup
    response = @request.delete('foo')
  end

  def test_get_none_match
    response = @request.put('foo', StringIO.new('test'))
    assert_equal '201', response.status

    etag = response.headers['etag'][0]
   
    response = @request.get('foo', :if_none_match => etag)
    assert_equal '304', response.status

    # cleanup
    response = @request.delete('foo')
  end

  def test_get_none_match_false
    response = @request.put('foo', StringIO.new('test1'))
    assert_equal '201', response.status
    etag1 = response.headers['etag'][0]
 
    response = @request.put('foo', StringIO.new('test2'))
    assert_equal '204', response.status
    etag2 = response.headers['etag'][0]
  
    response = @request.get('foo', :if_none_match => etag1)
    assert_equal '200', response.status
    assert_content_equals "test2", 'foo'

    # cleanup
    response = @request.delete('foo')
  end

  def test_expect
    body = StringIO.new "test"

    class << body
      def read *args
        raise "body was read"
      end
    end

    assert_nothing_raised(RuntimeError) do
      response = @request.put(testhome + 'foo', body, :content_type => 'text/plain')
      assert_equal '403', response.status
    end

  end

  def test_put_on_col
    response = @request.mkcol('collection')
    assert_equal '201', response.status

    response = @request.put('collection', @stream)
    assert_equal '405', response.status

    response = @request.delete('collection')
    assert_equal '204', response.status
  end

  def test_special_character_filenames
    new_file 'test~', StringIO.new("test")
    delete_file 'test~'
  end

  def test_pipelined_put_requests
    RubyDav::Request.module_eval do
      alias_method :request_orig, :request
      def request *args
        num_503_retries = 5
        response = request_orig *args

        while response.status == '503' and response.headers['retry-after'] and num_503_retries
          num_503_retries -= 1
          sleep(response.headers['retry-after'].to_s.to_i/100)
          response = request_orig *args
        end 
        response
      end
    end

    files = {}
    20.times do |i|
      filename = i.to_s
      files[filename] = "Contents of file '#{filename}'"
    end

    files.instance_variable_set :@req_creds, @creds.merge(:base_url => @host)
    def files.each_request_in_diff_thread &block
      self.map do |file|
        request = RubyDav::Request.new @req_creds
        Thread.new request, *file, &block
      end.each {|thr| thr.join }
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.delete filename
      assert ['204','404'].include?(response.status), "Deleting file #{filename}"
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.put filename, StringIO.new(filebody)
      assert_equal '201', response.status, "Put new file #{filename}"
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.get filename
      assert_equal '200', response.status, "Get on file #{filename}"
      assert_equal filebody, response.body, "File body of #{filename}"
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.put filename, StringIO.new(filebody)
      assert_equal '204', response.status, "Overwriting file #{filename}"
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.get filename
      assert_equal '200', response.status, "Get on file #{filename}"
      assert_equal filebody, response.body, "File body of #{filename}"
    end

    files.each_request_in_diff_thread do |request, filename, filebody|
      response = request.delete filename
      assert_equal '204', response.status, "Deleting file #{filename}"
    end

    RubyDav::Request.module_eval do
      alias_method :request, :request_orig
    end
  end
end
