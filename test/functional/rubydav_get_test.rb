require 'test/functional/functional_test_helper'


class RubyDavGetTest < RubyDavFunctionalTestCase
  def setup
    super
    @body = "test body"
    @host_path = URI.parse(@host).path
  end

  def test_get_request_success
    response = get_response_to_mock_get_request("200", @body)
    assert_equal @host_path, response.url
    assert_instance_of RubyDav::OkResponse, response
    assert_equal @body, response.body
  end

  create_get_tests "400","401","403","404","500"
  
  def assert_valid_get_response(response, code)
    assert_equal @host_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end
  
  def get_response_to_mock_get_request(code, body=nil)
    mresponse = mock_response(code, body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.get(@host)
  end
end
