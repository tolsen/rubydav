require 'test/functional/functional_test_helper'

class RubyDavAclTest < RubyDavFunctionalTestCase
  def setup
    super
    @host_path = URI.parse(@host).path
    @acl = RubyDav::Acl.new
    @acl << RubyDav::Ace.new(:grant, :all,false,"read")
  end
  
  create_acl_tests "200","400","401","403","404","405","409","412","500"

  def assert_valid_acl_response(response,code)
    assert_equal(response.url,@host_path)
    assert_instance_of(HTTP_CODE_TO_CLASS[code],response)
  end
  
  def get_response_to_mock_acl_request(code)
    mresponse = mock_response(code)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.acl(@host,@acl, :username=>@username,:password=>@password)
  end
  
end
