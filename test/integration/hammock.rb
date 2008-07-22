require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class HammockTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
    @auth_cookie = "authcookiethatneedstobeprovidedasaparameter"
  end

  BOUNDARY = 'f4k3b0und4ry'
  TESTC = "int main() { return 0; }"
  def test_upload_helper(body)
    
    response = @request.delete('upfile')
    response = @request.post("upfile?webdav-method=PUT&auth=#{@auth_cookie}", 
                             StringIO.new(multipart_body_helper(body)), 
                             :content_type => "multipart/form-data; boundary=" + BOUNDARY,
                             :cookie => {:auth => @auth_cookie})
    assert_equal '201', response.status

    # verify contents 
    assert_content_equals body, 'upfile'

    response = @request.delete('upfile')
  end

  def test_upload_simple
    test_upload_helper TESTC
  end
    
  def test_upload_trailing_CRLF
    test_upload_helper TESTC + "\r\n"
  end

  def test_upload_CRLF_body
    test_upload_helper TESTC + "\r\n" + TESTC
  end

  def test_upload_CRLF_body_and_trailing
    test_upload_helper TESTC + "\r\n" + TESTC + "\r\n"
  end

  def test_put_unaffected
    response = @request.delete('putfile')
    
    # verify that hammock does not translate PUT requests
    response = @request.put('putfile?webdav-method=GET', StringIO.new(multipart_body_helper(TESTC))) 
    assert_equal '201', response.status

    # verify that mod_upload did not change contents 
    assert_content_equals multipart_body_helper(TESTC), 'putfile'

    response = @request.delete('putfile')
  end

  def test_hdr_in_query_args
    response = @request.delete('putfile')
    
    response = @request.post('putfile?webdav-method=PUT', StringIO.new('test_file'), :cookie => {:auth => @auth_cookie}) 
    assert_equal '400', response.status

    response = @request.post("putfile?webdav-method=PUT&auth=#{@auth_cookie}", StringIO.new('test_file'), :cookie => {:auth => @auth_cookie})
    assert_equal '201', response.status

    response = @request.post("putfile?webdav-method=PUT&_hdr_If-None-Match=*&auth=#{@auth_cookie}", StringIO.new('asdf'), :cookie => {:auth => @auth_cookie})
    assert_equal '412', response.status

    response = @request.post("putfile?webdav-method=PUT&auth=#{@auth_cookie}", StringIO.new('test_file'), :cookie => {:auth => @auth_cookie}) 
    assert_equal '204', response.status

    response = @request.delete('putfile')
  end

  def make_file_multipart(field, filename, mime_type, content)
    return "Content-Disposition: form-data; name=\"#{field}\"; filename=\"#{filename}\"\r\n" +
           "Content-Type: #{mime_type}\r\n" + 
           "\r\n" + 
           "#{content}\r\n"
  end

  def multipart_body_helper(body)
    file_multipart = make_file_multipart('upfile', 'test.c', 'text/x-csrc', body)
    return '--' + BOUNDARY  + "\r\n" + file_multipart  + "--" + BOUNDARY  + "--\r\n"
  end
end
