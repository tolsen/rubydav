require 'test/unit/unit_test_helper'
require 'stringio'

class PutRequestTest < RubyDavUnitTestCase
  def setup
    super
    @body_stream = StringIO.new("test body stream")
    @host_path = URI.parse(@host).path
  end
  
  def test_put_request_validate
    mresponse = mock_response("201")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_put(req)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.put(@host,@body_stream)
    assert_equal(response.status,"201")
  end

  def test_put_html
    mresponse = mock_response("201")
    body = StringIO.new '<html/>'

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_put(req, body, 'text/html')}).and_return(mresponse)
    end

    response = RubyDav::Request.new.put(@host, body)
    assert_equal(response.status, "201")
  end

  def test_put_html_from_file
    mresponse = mock_response("201")
    body = File.new 'test/data/mini.html'

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_put(req, body, 'text/html')}).and_return(mresponse)
    end

    response = RubyDav::Request.new.put(@host, body)
    assert_equal(response.status, "201")
  end

  

  def validate_put(request, body = @body_stream, mimetype = 'text/plain')
    (request.is_a?(Net::HTTP::Put)) && 
      (request.path == @host_path) && 
      (request.body_stream == body) &&
      (request['Expect'] == '100-continue') &&
      (request['Content-Type'] == mimetype)
  end

end
