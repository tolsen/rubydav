require 'test/unit/unit_test_helper'
require 'stringio'

class PutRequestTest < RubyDavUnitTestCase

  def assert_put body = @body_stream, mimetype = 'text/plain', options = {}, &block
    mresponse = mock_response("201")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).
        with(on do |req|
               args = [req, body, mimetype]
               next (block_given? ? yield(*args) : validate_put(*args))
             end).
        and_return(mresponse)
    end
    response = RubyDav::Request.new.put @host, body, options
    assert_equal(response.status,"201")
  end
  
  
  def setup
    super
    @body_stream = StringIO.new("test body stream")
    @host_path = URI.parse(@host).path
  end

  def test_put__extra_headers
    assert_put(@body_stream, 'text/plain',
               :headers => { 'Random-Header' => 'foo' }) do |req, body, mimetype|
      next (validate_put(req, body, mimetype) && req['Random-Header'] == 'foo')
    end
  end
  
  def test_put_html
    assert_put StringIO.new('<html/>'), 'text/html'
  end

  def test_put_html_from_file
    assert_put File.new('test/data/mini.html'), 'text/html'
  end

  def test_put_request_validate
    assert_put
  end

  def test_put__string_body
    assert_put 'test body string' do |req, body, mimetype|
      next (validate_put_except_body(req, mimetype) &&
            req.body_stream.read == 'test body string')
    end
  end

  def validate_put_except_body request, mimetype
    return (request.is_a?(Net::HTTP::Put)) && 
      (request.path == @host_path) && 
      (request['Expect'] == '100-continue') &&
      (request['Content-Type'] == mimetype)
  end
  
  def validate_put request, body, mimetype
    return (validate_put_except_body(request, mimetype) &&
            (request.body_stream == body))
  end

end
