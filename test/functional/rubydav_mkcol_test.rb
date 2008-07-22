require 'test/functional/functional_test_helper'

class RubyDavMkcolTest < RubyDavFunctionalTestCase
  def setup
    super
    @collection_url = File.join(@host,"coll1")
    @coll_path = URI.parse(@collection_url).path
  end
  
  create_mkcol_tests "201","400","401","403","405","409","415","500","507"

  def assert_valid_mkcol_response(response,code)
    assert_equal @coll_path, response.url
    assert_instance_of  HTTP_CODE_TO_CLASS[code], response
  end
  
  def get_response_to_mock_mkcol_request(code)
    mresponse = mock_response(code)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.mkcol(@collection_url)
  end
end
