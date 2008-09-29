require 'test/unit/unit_test_helper'
require 'test/propfind_acl_test_helper'
require 'set'

class ResponseTest < Test::Unit::TestCase
  def setup
    @url = "www.example.org"
    @status = "200"
    @headers = {}
    @response = RubyDav::Response.create(@url, @status, @headers, "", :get)
  end
  
  def test_simple
    assert_instance_of RubyDav::Response, @response
  end
  
  def test_attributes
    assert_equal @url, @response.url
    assert_equal @status, @response.status
  end

  def test_headers
    headers = {"locktoken" => "random"}
    @response = RubyDav::Response.new(@url, @status, headers)
    assert_equal headers, @response.headers
  end

  def test_date
    headers = {"date" => [Time.now]}
    @response = RubyDav::Response.new(@url, @status, headers)
    assert_equal headers["date"][0], @response.date
  end
  
  def test_initialize
    response = RubyDav::Response.new(@url, @status, @headers)
    assert_equal @url, response.url
    assert_equal @status, response.status
    assert_equal @headers, response.headers
  end

end

class SuccessfulResponseTest < Test::Unit::TestCase
  def setup
    @response = RubyDav::SuccessfulResponse.create("www.example.org", "200", {},"",:get)
  end
  
  def test_simple
    assert_instance_of RubyDav::SuccessfulResponse, @response
  end
  
  def test_error
    assert !@response.error?
  end
end

class ErrorResponseTest < Test::Unit::TestCase
  def setup
    @response = RubyDav::ErrorResponse.create("www.example.org", "404", {}, "", :get)
  end

  def test_simple
    assert_instance_of RubyDav::ErrorResponse, @response
  end
  
  def test_error
    assert @response.error?
  end
end

class OkResponseTest < Test::Unit::TestCase
  def setup
    @body = "test body"
    @response = RubyDav::OkResponse.create("www.example.org", "200", {}, @body, :get)
  end
  
  def test_simple
    assert_instance_of RubyDav::OkResponse, @response
  end
  
  def test_body
    assert_equal @body, @response.body
  end
end

class MultiStatusResponseTest < RubyDavUnitTestCase
  def setup
    statuslist = []
    statuslist << ["412",["http://www.example.org/othercontainer/R2/","http://www.example.org/othercontainer/R3/"]]
    statuslist << ["403",["http://www.example.org/othercontainer/R4/R5/"]]
    
    @url = "www.example.org/othercontainer"
    @description = "Copied with errors"
    @body = @@response_builder.construct_copy_response(statuslist,@description)
    @response = RubyDav::MultiStatusResponse.create(@url,"207",{},@body,:copy)
    @responses = @response.responses
  end
  
  def test_simple
    assert_instance_of RubyDav::MultiStatusResponse, @response
    assert @response.error?
  end
  
  def test_attributes
    assert_equal @description, @response.description
    assert_equal @url, @response.url
    assert_equal "207", @response.status
  end

  def test_responses
    assert_equal 4, @responses.length
    
    assert_instance_of RubyDav::PreconditionFailedError, @responses[0]
    assert_equal "http://www.example.org/othercontainer/R2/", @responses[0].url
    
    assert_instance_of RubyDav::PreconditionFailedError, @responses[1]
    assert_equal "http://www.example.org/othercontainer/R3/", @responses[1].url
    
    assert_instance_of RubyDav::ForbiddenError, @responses[2]
    assert_equal "http://www.example.org/othercontainer/R4/R5/", @responses[2].url
    
    assert_equal @response, @responses[3]
  end
  
  def test_initialize
    responses = @responses.clone
    headers = Hash.new
    response = RubyDav::MultiStatusResponse.new(@url, '207', headers, @body, responses, :copy, "description")
    
    assert_equal @url, response.url
    assert_equal '207', response.status
    assert_equal headers, response.headers
    assert_equal @body, response.body
    responses << response
    assert_equal responses, response.responses
    assert_equal "description", response.description
  end
end

class MkcolResponseTest < RubyDavUnitTestCase
  def setup
    @url = "http://www.example.org/othercontainer"
    @body = @@response_builder.construct_mkcol_response([["200", nil, [["resourcetype","DAV:",nil],["email","http://limebits.com/ns/1.0/",nil]]]])
    @fail_body = @@response_builder.construct_mkcol_response([["424", nil, [["resourcetype","DAV:",nil]]],["403", nil, [["email","http://limebits.com/ns/1.0/",nil]]]])
    @response = RubyDav::MkcolResponse.create(@url,"201",{},@body,:mkcol_ext)
    @bad_response = RubyDav::MkcolResponse.create(@url,"424",{},@fail_body,:mkcol_ext)
  end
  
  def test_simple
    assert_instance_of RubyDav::MkcolResponse, @response
    assert_instance_of RubyDav::MkcolResponse, @bad_response
    assert_equal '201', @response.status
    assert @bad_response.error?
  end
  
  def test_prophash
    prophash = {
      RubyDav::PropKey.get("DAV:","resourcetype") => true,
      RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => true
    }
    assert_equal prophash, @response.propertyhash
  end
  
  def test_propertystatushash
    propstathash = { 
      RubyDav::PropKey.get("DAV:","resourcetype") => "200",
      RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => "200"
    }
    assert_equal propstathash, @response.propertystatushash
    propstathash = { 
      RubyDav::PropKey.get("DAV:","resourcetype") => "424",
      RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => "403"
    }
    assert_equal propstathash, @bad_response.propertystatushash
  end
  
end

class PropMultiResponseTest < RubyDavUnitTestCase
  @@body = nil
  @@response = nil
  
  def setup
    @url = "http://www.example.org/othercontainer"
    @child1 = File.join(@url,"child1")
    @child2 = File.join(@url,"child2")
    @grandchild = File.join(@child2,"subchild1")
    
    responsehash = {}
    responsehash[@url] = []
    responsehash[@url] << ["200", nil, [["creationdate","DAV:","1997-12-01T18:27:21-08:00"],["prop1","DAV:","val1"]]]
    responsehash[@url] << ["403", nil, [["bigbox","http://www.foo.bar/boxschema",""]]]
    responsehash[@child1] = [["200", nil, [["prop1","DAV:","val1"]]]]
    responsehash[@child2] = [["200", nil, [["prop1","DAV:","val1"]]]]
    responsehash[@grandchild] = [["200", nil,[["prop1","DAV:","val1"]]]]

    @@body ||= @@response_builder.construct_multiprop_response(responsehash)
    @@response ||= RubyDav::PropMultiResponse.create(@url,"207",{},@@body,:propfind)
    
    @response1 = @@response.children[File.basename(@child1)]
    @response2 = @@response.children[File.basename(@child2)]
    @response3 = @response2.children[File.basename(@grandchild)]
  end
  
  def test_simple
    assert_instance_of RubyDav::PropMultiResponse, @@response
  end

  def test_propertystatushash
    propstathash = { 
      prop1 => "200",
      RubyDav::PropKey.get("DAV:","creationdate") => "200",
      RubyDav::PropKey.get("http://www.foo.bar/boxschema","bigbox") => "403"
    }
    assert_equal propstathash, @@response.propertystatushash
  end
  
  def test_propfind_propertyhash
    prophash = {
      prop1 => "val1",
      RubyDav::PropKey.get("DAV:","creationdate") => "1997-12-01T18:27:21-08:00"
    }
    assert_equal prophash, @@response.propertyhash
  end
  
  def test_propertyhash_reader
    assert_equal "val1", @@response[prop1]
    assert_equal "1997-12-01T18:27:21-08:00", @@response[:creationdate]
    assert_nil @@response[RubyDav::PropKey.get("http://www.foo.bar/boxschema","bigbox")]
  end
  
  def test_statuses
    assert_equal "200", @@response.statuses(prop1)
    assert_equal "200", @@response.statuses(:creationdate)
    assert_equal "403", @@response.statuses(RubyDav::PropKey.get("http://www.foo.bar/boxschema","bigbox"))
  end

  def test_children
    prophash = {prop1 => "val1"}
    propstathash = {prop1 => "200"}
    
    assert_equal 2, @@response.children.length
    assert_propmultiresponse_object(@response1, prophash, propstathash, 0)
    assert_propmultiresponse_object(@response2, prophash, propstathash, 1)
    assert_propmultiresponse_object(@response3, prophash, propstathash, 0)
  end

  def test_parent
    assert_equal nil, @@response.parent
    assert_equal @@response, @response1.parent
    assert_equal @@response, @response2.parent
    assert_equal @response2, @response3.parent
  end

  def test_responses
    assert_equal [@response1], @response1.responses
    assert_equal [@response3], @response3.responses
    assert_equal [@response3, @response2], @response2.responses
    assert_equal 4, @@response.responses.length
    
    expected_response_set = [@@response, @response3, @response1, @response2].to_set
    assert_equal expected_response_set, @@response.responses.to_set
  end
  
  def test_proppatch_error
    responsehash = {}
    responsehash[@url] = []
    responsehash[@url] << ["403", nil, [["prop1","DAV:",""]]]
    responsehash[@url] << ["424", nil, [["prop2","DAV:",""]]]
    
    body = @@response_builder.construct_multiprop_response(responsehash)
    response = RubyDav::PropMultiResponse.create(@url, "207", {}, body, :proppatch)
    
    prophash = {}
    assert response.error?
    assert_equal prophash, response.propertyhash
  end


  def test_proppatch_success
    responsehash = {}
    responsehash[@url] = []
    responsehash[@url] << ["200", nil, [["prop1","DAV:",""],["prop2","DAV:",""]]]
    
    body = @@response_builder.construct_multiprop_response(responsehash)
    response = RubyDav::PropMultiResponse.create(@url, "207", {}, body, :proppatch)
    
    prophash = {
      prop1 => true,
      prop2 => true
    }
    assert !response.error?
    assert_equal prophash, response.propertyhash
  end
  
  def test_parse_body
    responsehash = {@url => [["200", nil, [["prop1","DAV:","value1"],["prop2","DAV:","value2"]]]]}
    body = @@response_builder.construct_multiprop_response(responsehash)
    urlhash = RubyDav::PropMultiResponse.parse_body body

    assert_equal "200", urlhash["http://www.example.org/othercontainer"][0][0]
    assert_equal 2, urlhash["http://www.example.org/othercontainer"][0][2].size
    assert_xml_matches urlhash["http://www.example.org/othercontainer"][0][2][prop1].to_s do |xml|
      xml.xmlns! 'DAV:'
      xml.prop1 'value1'
    end
    
    assert_xml_matches urlhash["http://www.example.org/othercontainer"][0][2][prop2].to_s do |xml|
      xml.xmlns! 'DAV:'
      xml.prop2 'value2'
    end
    
  end
  
  def test_createtree
    responsehash = {@url => [["200", nil, [["prop1","DAV:",""],["prop2","DAV:",""]]]]}
    body = @@response_builder.construct_multiprop_response(responsehash)
    response1 = RubyDav::PropMultiResponse.create(@url, "207", {}, body, :proppatch)
    assert_equal nil, response1.parent
    
    responsehash = {@child1 => [["200", nil, [["prop1","DAV:",""],["prop2","DAV:",""]]]]}
    body = @@response_builder.construct_multiprop_response(responsehash)
    response2 = RubyDav::PropMultiResponse.create(@child1, "207", {}, body, :proppatch)
    assert_equal nil, response2.parent
    
    urlhash = { @url => response1, @child1 => response2 }
    RubyDav::PropMultiResponse.createtree(urlhash)
    
    assert_equal response1, response2.parent
    assert_equal 1, response1.children.size
    assert_equal response2, response1.children[File.basename(@child1)]
  end
  
  def test_initialize_defaults
    headers = {}
    prophash = {}
    response = RubyDav::PropMultiResponse.new(@url, '207', headers, "fakebody")
    assert_equal @url, response.url
    assert_equal '207', response.status
    assert_equal headers, response.headers
    assert_equal "fakebody", response.body
    assert_equal prophash, response.propertyhash
    assert_equal prophash, response.propertystatushash
    assert !response.error?
  end

  def test_initialize
    headers = {}
    propertyhash = {prop1 => "val1"}
    propertyfullhash = {prop1 => "<prop1 xmlns='DAV:'>val1</prop1>"}
    propertystatushash = {prop1 => "200"}
    response = RubyDav::PropMultiResponse.new(@url, '207', headers, "fakebody", propertyhash, propertystatushash, {}, propertyfullhash, true)
    assert_equal @url, response.url
    assert_equal '207', response.status
    assert_equal headers, response.headers
    assert_equal "fakebody", response.body
    assert_equal propertyhash, response.propertyhash
    assert_equal propertystatushash, response.propertystatushash
    assert_equal propertyfullhash, response.propertyfullhash
      
    assert response.error?
  end


  def prop1() prop_n(1); end
  def prop2() prop_n(2); end
  def prop_n(n) RubyDav::PropKey.get("DAV:", "prop#{n}"); end
  
end

class PropfindAclResponseTest < RubyDavUnitTestCase
  include PropfindAclTestHelper
  def get_response(url,body)
    RubyDav::PropfindAclResponse.create(url,"207",{},body,:propfind_acl)
  end
end

class PropfindCupsResponseTest < RubyDavUnitTestCase
  @@body = nil
  @@response = nil

  def setup
    @url = "http://www.example.org/othercontainer"
    @child = File.join(@url,"child")
    @grandchild = File.join(@child,"grandchild")
    
    responsehash = {}
    responsehash[@url] = ["200", nil, ["read","write","read-acl"]]
    responsehash[@child] = ["200", nil, ["read"]]
    responsehash[@grandchild] = ["403", nil, []]

    @@body ||= @@response_builder.construct_propfindcups_response(responsehash)
    @@response ||= RubyDav::PropfindCupsResponse.create(@url,"207",{},@@body,:propfind_cups)
  end

  def test_privileges
    assert_equal ["read", "write", "read-acl"], @@response.privileges
  end
  
  def test_acl_status
    assert_equal "200", @@response.cups_status
  end

  def test_children
    response1 = @@response.children[File.basename(@child)]
    response2 = response1.children[File.basename(@grandchild)]

    assert_equal 1, @@response.children.length
    
    assert_propcupsresponse_object(response1, ["read"], "200", 1)
    assert_propcupsresponse_object(response2, [], "403", 0)
  end

  def test_initialize
    headers = {}
    response = RubyDav::PropfindCupsResponse.new(@url, '207', headers, "fakebody",
                                                 ["write", "read"], "200", nil)
    assert_equal @url, response.url
    assert_equal '207', response.status
    assert_equal headers, response.headers
    assert_equal "fakebody", response.body
    assert_equal ["write", "read"], response.privileges
    assert_equal '200', response.cups_status
  end
end
