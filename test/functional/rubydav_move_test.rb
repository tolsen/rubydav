require 'test/functional/functional_test_helper'


class RubyDavMoveTest < RubyDavFunctionalTestCase
  def setup
    super
    @srcurl = File.join(@host,"src")
    @desturl = File.join(@host,"dest")
    @srcpath = URI.parse(@srcurl).path
  end
  
  create_move_tests "201", "204", "400", "401", "403", "409", "412", "500"

  def assert_valid_move_response(response,code)
    assert_equal @srcpath, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end
  
  def get_response_to_mock_move_request(code, body=nil)
    mresponse = mock_response(code, body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.move(@srcurl, @desturl)
  end
  
end
