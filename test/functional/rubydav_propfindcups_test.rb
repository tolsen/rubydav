require 'test/functional/functional_test_helper'

class RubyDavPropfindCupsTest < RubyDavFunctionalTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  create_propfind_cups_tests "400", "401", "403", "404", "500"
  
  def assert_valid_propfind_cups_response(response, code)
    assert_equal @url_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end

  def test_propfind_cups_depth0
    responsehash = {}
    responsehash["http://www.example.org/dir"] = ["200",nil,["read","write"]]
    body = @@response_builder.construct_propfindcups_response(responsehash)
    response = get_response_to_mock_propfind_cups_request("207", body)
    
    assert_equal "http://www.example.org/dir", response.url
    privileges= ["read","write"]
    
    assert_propcupsresponse_object(response, privileges, "200", 0)
  end
  
  def test_propfind_cups_multistatus
    responsehash = {}
    privileges = ["read", "write"]
    
    responsehash["http://www.example.org"] = ["200", nil, privileges]
    responsehash["http://www.example.org/dir1"] = ["200", nil, privileges]
    responsehash["http://www.example.org/dir2"] = ["200", nil, privileges]
    responsehash["http://www.example.org/dir1/subdir1"] = ["403", nil, []]
    body = @@response_builder.construct_propfindcups_response(responsehash)
    
    response = get_response_to_mock_propfind_cups_request("207",body)
    response1 = response.children["dir1"]
    response2 = response.children["dir2"]
    response3 = response1.children["subdir1"]

    assert_propcupsresponse_object(response, privileges, "200", 2)
    assert_propcupsresponse_object(response1, privileges, "200", 1)
    assert_propcupsresponse_object(response2, privileges, "200", 0)
    assert_propcupsresponse_object(response3, [], "403", 0)
  end
  
  def get_response_to_mock_propfind_cups_request(code,body=nil)
    mresponse = mock_response(code,body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind_cups(@url)
  end
end
