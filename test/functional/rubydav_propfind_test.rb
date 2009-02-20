require 'test/functional/functional_test_helper'

class RubyDavPropfindTest < RubyDavFunctionalTestCase
  
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  def test_propfind_multistatus_depth_0
    responsehash = {}
    responsehash["/limespot/myhome"] = []
    responsehash["/limespot/myhome"] << ["200", nil, [["creationdate","DAV:","1997-12-01T18:27:21-08:00"], ["prop1","DAV:","val1"]]]
    responsehash["/limespot/myhome"] << ["403", nil, [["bigbox","http://www.foo.bar/boxschema/",""]]]
    
    body = @@response_builder.construct_multiprop_response(responsehash)

    pk1 = RubyDav::PropKey.get("DAV:","creationdate")
    pk2 = RubyDav::PropKey.get("DAV:","prop1")
    pk3 = RubyDav::PropKey.get("http://www.foo.bar/boxschema/","bigbox")
    statuses = {'/limespot/myhome' => {pk1 => "200",pk2 => "200",pk3 => "403"} }
    properties = { '/limespot/myhome' => {pk1 => "1997-12-01T18:27:21-08:00",pk2 => "val1"} }
    
    response = get_response_to_mock_propfind_request("207",body)

    assert_propstat_response response, properties, statuses
  end
  
  def test_propfind_multistatus_depth_infinity
    responsehash = {}
    propstat = [["200", nil, [["prop1","DAV:","val1"]]]]
    urls = ["/limespot/myhome", "/limespot/myhome/a", "/limespot/myhome/b", "/limespot/myhome/b/c"]
    urls.each do |url|
      responsehash[url] = propstat
    end
    body = @@response_builder.construct_multiprop_response(responsehash)
    
    pk = RubyDav::PropKey.get("DAV:","prop1")
    prophash = {pk => "val1"}
    propstathash = {pk => "200"}

    properties = urls.inject({}) { |h, u| h[u] = prophash; h }
    statuses = urls.inject({}) { |h, u| h[u] = propstathash; h }

    response = get_response_to_mock_propfind_request("207", body)
    
    assert_propstat_response response, properties, statuses
  end
    
  create_propfind_tests "400", "401", "403", "404", "500"
  
  def assert_valid_propfind_response(response, code)
    assert_equal @url_path, response.url
    assert_instance_of HTTP_CODE_TO_CLASS[code], response
  end

  def get_response_to_mock_propfind_request(code, body=nil)
    mresponse = mock_response(code, body)
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url, RubyDav::INFINITY, :allprop)
  end

end
