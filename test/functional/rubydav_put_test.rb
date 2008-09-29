require 'test/functional/functional_test_helper'
require 'stringio'

class RubyDavPutTest < RubyDavFunctionalTestCase
  def setup
    super
    @body_stream = StringIO.new("test body stream")
    @host_path = URI.parse(@host).path
  end
  
  create_put_tests "201", "204", "400", "401", "403", "405", "409", "412", "500", "507"
  
  def assert_valid_put_response(response,code)
    assert_equal @host_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end
  
  def get_response_to_mock_put_request(code)
    mresponse = mock_response(code)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.put(@host, @body_stream)
  end
end
