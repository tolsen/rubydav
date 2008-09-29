require 'test/functional/functional_test_helper'
require 'test/propfind_acl_test_helper'

class RubyDavPropfindAclTest < RubyDavFunctionalTestCase
  include PropfindAclTestHelper

  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  create_propfind_acl_tests "400", "401", "403", "404", "500"
  
  def assert_valid_propfind_acl_response(response,code)
    assert_equal @url_path, response.url
    assert_instance_of(HTTP_CODE_TO_CLASS[code.to_s],response)
  end
  
  def get_response(url,body)
    @url = url
    get_response_to_mock_propfind_acl_request("207",body)
  end
  

  def get_response_to_mock_propfind_acl_request(code,body=nil)
    mresponse = mock_response(code,body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind_acl(@url)
  end
end
