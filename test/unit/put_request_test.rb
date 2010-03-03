require 'test/unit/unit_test_helper'
require 'stringio'

class PutRequestTest < RubyDavUnitTestCase

  def assert_put body = @body_stream, mimetype = 'text/plain', options = {}, &block
    mresponse = mock_response("201")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).
        with(on { |req| validate_put(req, body, mimetype, &block) }).
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
               :headers => { 'Random-Header' => 'foo' }) do |req|
      next req['Random-Header'] == 'foo'
    end
  end
  
  def test_put_request_validate
    assert_put
  end

  def test_put_html
    assert_put StringIO.new('<html/>'), 'text/html'
  end

  def test_put_html_from_file
    assert_put File.new('test/data/mini.html'), 'text/html'
  end

  def validate_put request, body, mimetype, &block
    result = (request.is_a?(Net::HTTP::Put)) && 
      (request.path == @host_path) && 
      (request.body_stream == body) &&
      (request['Expect'] == '100-continue') &&
      (request['Content-Type'] == mimetype)

    result = result && yield(request) if block_given?
    return result
  end

end
