require 'test/functional/functional_test_helper'

class RubyDavDeleteTest < RubyDavFunctionalTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  create_delete_tests "204", "400", "401", "403", "404", "409", "500"

  def assert_valid_delete_response(response, code)
    assert_equal @url_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end
  
  def get_response_to_mock_delete_request(code)
    mresponse = mock_response(code)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.delete(@url)
  end
end
