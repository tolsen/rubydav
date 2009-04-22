require 'test/unit'
require 'rubygems'
require 'flexmock'

require 'lib/rubydav'
require '../inspector/lib/inspector'
require 'test/response_builder'

class Net::HTTP
  def self.start(host,port,&block)
    http = Net::HTTP.new(host,port)
    if block_given?
      yield http
    else
      return http
    end
  end
end

class RubyDavTestCase < Test::Unit::TestCase
  include FlexMock::TestCase
  
  @@response_builder = ResponseBuilder.new
  
  def setup
    @host = "http://www.example.com/limespot"
    @host_path = "/limespot"
    @httpv = "1.1"
  end
  
  def mock_response(code, body=nil, headers = {})
    code_s = code.to_s
    response = Net::HTTPResponse::CODE_TO_OBJ[code_s].new @httpv, code_s, HTTP_CODE_TO_MSG[code]
    flexstub(response) do |res|
      res.should_receive(:body).and_return(body)
    end
    response.initialize_http_header headers unless headers.empty?
    response
  end

  def test_dummy
    assert true
  end

  HTTP_CODE_TO_MSG = { #both
    "200" => "OK",
    "201" => "Created",
    "204" => "No Content",
    "207" => "MultiStatus",
    "400" => "Bad Request",
    "401" => "Unauthorized",
    "403" => "Forbidden",
    "404" => "Not Found",
    "405" => "Method Not Allowed",
    "408" => "Request Timeout",
    "409" => "Conflict",
    "412" => "Precondition Failed",
    "413" => "Request Entity Too Large",
    "414" => "Request URI Too Large",
    "415" => "Unsupported Media Type",
    "500" => "Internal Server Error",
    "501" => "Not Implemented",
    "503" => "Service Unavailable",
    "505" => "Http Version Not Supported",
    "507" => "Insufficient Storage"
  } 
  
  def create_acl_lists acelist
    acl = RubyDav::Acl.new
    protected_acl = RubyDav::Acl.new
    inherited_acl = RubyDav::Acl.new
    
    acelist.each do |(inherited_url, action, principal, protected, *privileges)|
      acl_object = protected ? protected_acl : acl
      if inherited_url
        inherited_acl << RubyDav::InheritedAce.new(inherited_url,
                                                   action, principal,
                                                   protected, *privileges)
      else
        acl_object << RubyDav::Ace.new(action, principal,
                                       protected, *privileges)
      end
    end
    
    allacl = RubyDav::Acl.new
    allacl.concat acl
    allacl.concat protected_acl
    allacl.concat inherited_acl
    return acl, protected_acl, inherited_acl, allacl
  end


  def assert_propmultiresponse_object(response, prophash, propstathash, num_of_children)
    assert_instance_of RubyDav::PropMultiResponse, response
    assert_equal num_of_children, response.children.length
    assert_equal prophash, response.propertyhash
    assert_equal propstathash, response.propertystatushash
  end

  def assert_propcupsresponse_object(response, privileges, cups_status, num_of_children)
    assert_instance_of RubyDav::PropfindCupsResponse, response
    assert_equal num_of_children, response.children.length
    assert_equal privileges, response.privileges
    assert_equal cups_status, response.cups_status
  end

  # properties is a hash from urls -> prop_keys -> inner_values
  # statuses is a hash from urls -> prop_keys -> statuses
  def assert_propstat_response response, properties, statuses
    assert_instance_of RubyDav::PropstatResponse, response

    assert_equal properties.keys.sort, statuses.keys.sort
    assert_equal properties.keys.sort, response.resources.keys.sort

    response.resources.each do |url, results|

      successful_results = results.reject do |pk, r|
        r.inner_value.nil? || r.inner_value.strip.empty?
      end

      successful_keys = successful_results.keys.sort
      assert_equal properties[url].keys.sort, successful_keys

      successful_keys.each do |pk|
        assert_equal properties[url][pk], results[pk].inner_value
      end

      keys = results.keys.sort
      assert_equal statuses[url].keys.sort, results.keys.sort

      keys.each do |pk|
        assert_equal statuses[url][pk], results[pk].status
      end
    end
  end
  
      
    
    
end
