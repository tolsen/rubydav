require 'test/functional/functional_test_helper'

class RubyDavProppatchTest < RubyDavFunctionalTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
    @properties = { @url => {} }
  end
  
  def test_proppatch_response_failure
    responsehash = {}
    responsehash[@url] = []
    responsehash[@url] << ["424", nil, [["myprop","DAV:",""], ["prop1","http://www.example.org/namespace",""]]]
    responsehash[@url] << ["409", nil, [["property1","DAV:",""]]] 
    body = @@response_builder.construct_multiprop_response(responsehash)

    response = get_response_to_mock_proppatch_request("207",body)
    assert_equal @url_path, response.url
    statuses = { @url =>
      { RubyDav::PropKey.get("DAV:","myprop") => "424",
        RubyDav::PropKey.get("http://www.example.org/namespace","prop1") => "424",
        RubyDav::PropKey.get("DAV:","property1") => "409"} }
    assert_propstat_response response, @properties, statuses
  end
  
  def test_proppatch_response_success
    responsehash = {}
    responsehash[@url] = []
    responsehash[@url] << ["200", nil, [["myprop","DAV:",""], ["property1","DAV:",""]]]
    body = @@response_builder.construct_multiprop_response(responsehash)

    pk1 = RubyDav::PropKey.get("DAV:", "myprop")
    pk2 = RubyDav::PropKey.get("DAV:", "property1")

    response = get_response_to_mock_proppatch_request("207", body)

    statuses = { @url => {pk1 => "200", pk2 => "200"} }
    assert_propstat_response response, @properties, statuses
  end
  
  create_proppatch_tests "400","401","403","404","500"

  def assert_valid_proppatch_response(response,code)
    assert_equal(response.url,@url_path)
    assert_instance_of(HTTP_CODE_TO_CLASS[code],response)
  end
  
  def get_response_to_mock_proppatch_request(code,body=nil)
    mresponse = mock_response(code, body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.proppatch(@url,{:displayname =>"tempname"})
  end
  
  def assert_propmultiresponse_object(response,prophash,propstathash,num_of_children)
    assert_instance_of RubyDav::PropMultiResponse, response
    assert_equal num_of_children, response.children.length
    assert_equal prophash, response.propertyhash
    assert_equal propstathash, response.propertystatushash
  end
end
