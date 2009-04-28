require 'test/functional/functional_test_helper'

class RubyDavCopyTest < RubyDavFunctionalTestCase
  def setup
    super
    @srcurl = File.join(@host,"src")
    @desturl = File.join(@host,"dest")
    @src_path = URI.parse(@srcurl).path
  end
  
  def test_copy_multistatus
    statuslist = []
    statuslist << ["412",["http://www.example.org/othercontainer/R2/","http://www.example.org/othercontainer/R3/"]]
    statuslist << ["403",["http://www.example.org/othercontainer/R4/R5/"]]
    body = @@response_builder.construct_copy_response(statuslist)

    response = get_response_to_mock_copy_request("207",body)

    assert_instance_of RubyDav::MultiStatusResponse, response
    assert_equal @src_path, response.url
    assert response.error?

    # TODO: consolidate this with MultiStatusResponseTest#test_responses
    # in unit tests
    
    prefix = 'http://www.example.org/othercontainer/'
    responses = response.responses
    assert_equal 3, responses.length

    %w(R2/ R3/ R4/R5/).each do |suffix|
      url = prefix + suffix
      assert_equal url, responses[url].href
    end

    assert_equal '412', responses[prefix + 'R2/'].status
    assert_equal '412', responses[prefix + 'R3/'].status
    assert_equal '403', responses[prefix + 'R4/R5/'].status
  end
  
  create_copy_tests "201","204","400","401","403","409","412","500","507"

  def assert_valid_copy_response(response, code)
    assert_equal @src_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end

  
  def get_response_to_mock_copy_request(code, body=nil)
    mresponse = mock_response(code, body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.copy(@srcurl, @desturl)
  end
end
