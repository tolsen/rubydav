require 'test/unit/assertions'
require File.dirname(__FILE__) + '/../../lib/rubydav.rb'
require File.dirname(__FILE__) + '/../../lib/rubydav/acl.rb'
require File.dirname(__FILE__) + '/../../lib/limestone.rb'

module WebDavTestUtils
  include Test::Unit::Assertions
  
  # delete and mkcol new coll
  def new_coll(coll, creds={})
    delete_coll(coll, creds)
    response = @request.mkcol(coll, creds)
    assert_equal '201', response.status
  end
    
  # delete and put new file
  def new_file(file, body=@stream, creds={})
    delete_file(file, creds)

    response = @request.put(file, body, creds)
    assert_equal '201', response.status
  end

  # delete collection
  def delete_coll(coll, creds={})
    response = @request.delete(coll, creds)
    assert_does_not_exist(coll, creds)
  end

  def assert_does_not_exist(coll, creds={})
    response = @request.propfind(coll, 0, :resourcetype, creds)
    assert_equal '404', response.status
  end

  def assert_exists(url, creds={})
    response = @request.propfind(url, 0, :resourcetype, creds)
    assert !response.error?
  end

  # move collection
  def move_coll(src, dst, overwrite=true, creds={})
    @request.move(src, dst, overwrite, creds)
  end

  # delete file
  def delete_file(file, creds={})
    response = @request.delete(file, creds)
    response = @request.get(file, creds)
    assert_equal '404', response.status
  end
    
  def get_home_path username
    return '/home/' + username
  end

  # NOTE: Currently, very specific to limestone. 
  # Correct way to do this is principal-property-search REPORT.
  def get_principal_uri name, *host
    if host.empty?
      # relative URI
      principal_uri = '/users/' + name
    else
      #absolute URI
      principal_uri = host[0] + '/users/' + name
    end
    return principal_uri
  end
  
  # required to convert relative paths into absolute URIs
  def baseuri
    scheme, userinfo, host, port = URI.split(@host)
    uri = "#{scheme}://#{host}"
    uri += ":#{port}" unless port.nil?
    return uri
  end

  def assert_content_equals(expcontent, file, creds={})
    response = @request.get(file, creds)
    assert_equal '200', response.status
    assert_equal expcontent, response.body
  end

  # add an ace and update the acl of the resource, returns the new acl
  def add_ace_and_set_acl(resource, ace, creds={})
    acl = get_acl resource, creds

    unless acl.include? ace
      # prepend the new Ace
      acl.unshift ace

      # set the access control properties of the resource
      response = @request.acl(resource, acl, creds)
      assert_equal '200', response.status
    end

    return acl
  end

  def get_acl(resource, creds={})
    response = @request.propfind resource, 0, :acl, creds
    assert_equal '207', response.status
    return response[:acl].acl.modifiable
  end

  # lock resource and return activelock
  def lock path, options = {}
    response = @request.lock path, options
    assert_equal '200', response.status
    return response.active_lock
  end
  
  
  def assert_dav_error(response_or_dav_error, condition)
    dav_error = if response_or_dav_error.kind_of?(RubyDav::Response)
                  assert_not_nil response_or_dav_error.dav_error
                  response_or_dav_error.dav_error
                else
                  response_or_dav_error
                end
    assert_equal condition, dav_error.condition.name
  end

  def resize_file(path, size)
    if !(File.exists? path) || ((File.size path) != size)
        `dd if=/dev/zero of=#{path} bs=#{size} count=1 status=noxfer 2> /dev/null`
    end
  end
  
  def put_file_w_size path, size, creds={}
    resize_file @bigfilepath, size
    @bigfile = File.read @bigfilepath
    @bigstream = StringIO.new @bigfile
    response = @request.put(path, @bigstream, creds)
    assert (response.status =~ /20[1|4]/)
  end

  def checkout_put_checkin url, body=@stream, creds={}

    response = @request.checkout url, 0, creds
    assert_equal '200', response.status

    response = @request.put(url, body, creds)
    assert_equal '204', response.status

    response = @request.checkin url, 0, 0, creds
    assert_equal '201', response.status

  end

  def full_path relative_path
    URI.parse(@host).path + relative_path
  end
  
  def test_stream() StringIO.new('test'); end

  def get_uuid bit
    response = @request.propfind(bit, 0, :"resource-id")
    assert_equal '207', response.status
    value = RubyDav.find_first_text response[:"resource-id"].element, "D:href"
    return value.to_s.gsub(/(.*:)/, '').gsub(/-/,'')
  end

  def bm_key name
    RubyDav::PropKey.get('http://limebits.com/ns/1.0/', name )
  end

  def mark bit, name, value, creds={}
    uuid = get_uuid bit
    tagp_key = bm_key name
    uniq = Time.new.to_f * 1000

    response = @request.mkcol('/bitmarks/' + uuid, creds.merge(:if_none_match => '*'))
    new_coll '/bitmarks/' + uuid + '/' + uniq.to_s
    response = @request.proppatch('/bitmarks/' + uuid + '/' + uniq.to_s, { tagp_key => value }, creds)
    assert_equal '207', response.status
    assert_equal '200', response[tagp_key].status
  end

end
