require 'test/unit/unit_test_helper'
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

# class MkcolResponseTest < RubyDavUnitTestCase
#   def setup
#     @url = "http://www.example.org/othercontainer"
#     @body = @@response_builder.construct_mkcol_response([["200", nil, [["resourcetype","DAV:",nil],["email","http://limebits.com/ns/1.0/",nil]]]])
#     @fail_body = @@response_builder.construct_mkcol_response([["424", nil, [["resourcetype","DAV:",nil]]],["403", nil, [["email","http://limebits.com/ns/1.0/",nil]]]])
#     @response = RubyDav::MkcolResponse.create(@url,"201",{},@body,:mkcol_ext)
#     @bad_response = RubyDav::MkcolResponse.create(@url,"424",{},@fail_body,:mkcol_ext)
#   end
  
#   def test_simple
#     assert_instance_of RubyDav::MkcolResponse, @response
#     assert_instance_of RubyDav::MkcolResponse, @bad_response
#     assert_equal '201', @response.status
#     assert @bad_response.error?
#   end
  
#   def test_prophash
#     prophash = {
#       RubyDav::PropKey.get("DAV:","resourcetype") => true,
#       RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => true
#     }
#     assert_equal prophash, @response.propertyhash
#   end
  
#   def test_propertystatushash
#     propstathash = { 
#       RubyDav::PropKey.get("DAV:","resourcetype") => "200",
#       RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => "200"
#     }
#     assert_equal propstathash, @response.propertystatushash
#     propstathash = { 
#       RubyDav::PropKey.get("DAV:","resourcetype") => "424",
#       RubyDav::PropKey.get("http://limebits.com/ns/1.0/","email") => "403"
#     }
#     assert_equal propstathash, @bad_response.propertystatushash
#   end
  
# end

class PropstatResponseTest < Test::Unit::TestCase

  def assert_property_result prop, pk, result, status = '200', error = nil
    element = REXML::XPath.first prop, pk.name, '' => pk.ns
    assert_equal pk, result.prop_key
    assert_equal status, result.status
    assert_equal error, result.error
    assert_equal element.to_s, result.element.to_s
  end

  # expected is an array of 3-tuples: (status, dav_error, props)
  def assert_propstats expected, parent_elem
    expected_h = expected.inject({}) { |h, v| h[v[0]] = v; h }

    propstat_infos =
      RubyDav::PropstatResponse.send :parse_propstats, parent_elem
    
    assert_equal expected.size, propstat_infos.size

    statuses = propstat_infos.map { |i| i.status }
    assert_equal expected_h.keys.sort, statuses.sort

    propstat_infos.each do |psi|
      expected_tuple = expected_h[psi.status]
      
      assert_equal expected_tuple[1], psi.dav_error
      assert_equal expected_tuple[2].sort, psi.props.sort
    end
  end
  

  def get_prop response, status = 'HTTP/1.1 200 OK'
    REXML::XPath.first(response,
                       "propstat/status[.='#{status}']/../prop",
                       '' => 'DAV:')
  end
  
  def get_response root, url
      REXML::XPath.first(root,
                         "/multistatus/response/href[.='#{url}']/..",
                         '' => 'DAV:')
  end

  def expected_props prop_element, prop_keys
    return prop_keys.inject({}) do |h, k|
      h[k] = REXML::XPath.first(prop_element, "P:#{k.name}", 'P' => k.ns)
      next h
    end
  end
  
  def setup
    @propfind_response_str = <<EOS
  <?xml version="1.0" encoding="utf-8" ?>
  <D:multistatus xmlns:D="DAV:">
    <D:response>
      <D:href>/container/</D:href>
      <D:propstat>
        <D:prop xmlns:R="http://ns.example.com/boxschema/">
          <R:bigbox><R:BoxType>Box type A</R:BoxType></R:bigbox>
          <R:author><R:Name>Hadrian</R:Name></R:author>
          <D:creationdate>1997-12-01T17:42:21-08:00</D:creationdate>
          <D:displayname>Example collection</D:displayname>
          <D:resourcetype><D:collection/></D:resourcetype>
          <D:supportedlock>
            <D:lockentry>
              <D:lockscope><D:exclusive/></D:lockscope>
              <D:locktype><D:write/></D:locktype>
            </D:lockentry>
            <D:lockentry>
              <D:lockscope><D:shared/></D:lockscope>
              <D:locktype><D:write/></D:locktype>
            </D:lockentry>
          </D:supportedlock>
        </D:prop>
        <D:status>HTTP/1.1 200 OK</D:status>
      </D:propstat>
    </D:response>
    <D:response>
      <D:href>/container/front.html</D:href>
      <D:propstat>
        <D:prop xmlns:R="http://ns.example.com/boxschema/">
          <R:bigbox><R:BoxType>Box type B</R:BoxType>
          </R:bigbox>
          <D:creationdate>1997-12-01T18:27:21-08:00</D:creationdate>
          <D:displayname>Example HTML resource</D:displayname>
          <D:getcontentlength>4525</D:getcontentlength>
          <D:getcontenttype>text/html</D:getcontenttype>
          <D:getetag>"zzyzx"</D:getetag>
          <D:getlastmodified
            >Mon, 12 Jan 1998 09:25:56 GMT</D:getlastmodified>
          <D:resourcetype/>
          <D:supportedlock>
            <D:lockentry>
              <D:lockscope><D:exclusive/></D:lockscope>
              <D:locktype><D:write/></D:locktype>
            </D:lockentry>
            <D:lockentry>
              <D:lockscope><D:shared/></D:lockscope>
              <D:locktype><D:write/></D:locktype>
            </D:lockentry>
          </D:supportedlock>
        </D:prop>
        <D:status>HTTP/1.1 200 OK</D:status>
      </D:propstat>
    </D:response>
  </D:multistatus>
EOS

    propfind_response_root = REXML::Document.new(@propfind_response_str).root
    @container_response = get_response propfind_response_root, '/container/'
    @front_response =
      get_response propfind_response_root, '/container/front.html'

    @container_prop = get_prop @container_response
    @front_prop = get_prop @front_response
    @props = {
      '/container/' => @container_prop,
      '/container/front.html' => @front_prop
    }

    @container_prop_keys =
      [
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'bigbox'),
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'author'),
       RubyDav::PropKey.get('DAV:', 'creationdate'),
       RubyDav::PropKey.get('DAV:', 'displayname'),
       RubyDav::PropKey.get('DAV:', 'resourcetype'),
       RubyDav::PropKey.get('DAV:', 'supportedlock')
      ]

    @front_prop_keys =
      [
       RubyDav::PropKey.get('http://ns.example.com/boxschema/', 'bigbox'),
       RubyDav::PropKey.get('DAV:', 'creationdate'),
       RubyDav::PropKey.get('DAV:', 'displayname'),
       RubyDav::PropKey.get('DAV:', 'getcontentlength'),
       RubyDav::PropKey.get('DAV:', 'getcontenttype'),
       RubyDav::PropKey.get('DAV:', 'getetag'),
       RubyDav::PropKey.get('DAV:', 'getlastmodified'),
       RubyDav::PropKey.get('DAV:', 'resourcetype'),
       RubyDav::PropKey.get('DAV:', 'supportedlock')
      ]


    @expected_container_props =
      expected_props @container_prop, @container_prop_keys
    @expected_front_props =
      expected_props @front_prop, @front_prop_keys

    @response =
      RubyDav::PropstatResponse.create('/container/', '207', {},
                                          @propfind_response_str, :propfind)
    @propfind2_response_str = <<EOS
  <?xml version="1.0" encoding="utf-8" ?>
  <D:multistatus xmlns:D="DAV:">
    <D:response>
      <D:href>/container2/</D:href>
      <D:propstat>
        <D:prop>
          <D:displayname>Example collection</D:displayname>
        </D:prop>
        <D:status>HTTP/1.1 200 OK</D:status>
      </D:propstat>
      <D:propstat>
        <D:prop>
          <D:resourcetype/>
        </D:prop>
        <D:status>HTTP/1.1 401 Unauthorized</D:status>
      </D:propstat>
      <D:propstat>
        <D:prop>
          <D:supportedlock/>
        </D:prop>
        <D:status>HTTP/1.1 403 Forbidden</D:status>
      </D:propstat>
    </D:response>
  </D:multistatus>
EOS
    @propfind2_response_root =
      REXML::Document.new(@propfind2_response_str).root
    @container2_response =
      get_response @propfind2_response_root, '/container2/'
    @container2_200_prop = get_prop @container2_response
    @container2_401_prop = get_prop @container2_response, 'HTTP/1.1 401 Unauthorized'
    @container2_403_prop = get_prop @container2_response, 'HTTP/1.1 403 Forbidden'

    @displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    @resourcetype_pk = RubyDav::PropKey.get('DAV:', 'resourcetype')
    @supportedlock_pk = RubyDav::PropKey.get('DAV:', 'supportedlock')

    @container2_200_props =
      expected_props @container2_200_prop, [@displayname_pk]
    @container2_401_props =
      expected_props @container2_401_prop, [@resourcetype_pk]
    @container2_403_props =
      expected_props @container2_403_prop, [@supportedlock_pk]

    @response2 =
      RubyDav::PropstatResponse.create('/container2/', '207', {},
                                          @propfind2_response_str, :propfind)

  end

  def test_create
    assert_instance_of RubyDav::PropstatResponse, @response
    assert_instance_of Hash, @response.resources
  end

  def test_parse_body
    urlhash =
      RubyDav::PropstatResponse.send :parse_body, @propfind_response_str
    expected_urls = ['/container/', '/container/front.html'].sort
    assert_equal expected_urls, urlhash.keys.sort

    assert_equal @container_prop_keys.sort, urlhash['/container/'].keys.sort
    assert_equal @front_prop_keys.sort, urlhash['/container/front.html'].keys.sort

    urlhash.each do |url, props|
      props.each do |pk, result|
        assert_property_result @props[url], pk, result
      end
    end
  end

  def test_parse_body2
    urlhash =
      RubyDav::PropstatResponse.send :parse_body, @propfind2_response_str
    assert_equal ['/container2/'], urlhash.keys

    container2_results = urlhash['/container2/']

    expected_pks = [@displayname_pk, @resourcetype_pk, @supportedlock_pk].sort
    assert_equal expected_pks, container2_results.keys.sort

    assert_property_result(@container2_200_prop, @displayname_pk,
                           container2_results[@displayname_pk], '200')
    assert_property_result(@container2_401_prop, @resourcetype_pk,
                           container2_results[@resourcetype_pk], '401')
    assert_property_result(@container2_403_prop, @supportedlock_pk,
                           container2_results[@supportedlock_pk], '403')
  end
  
  
  def test_parse_prop
    prophash = RubyDav::PropstatResponse.send :parse_prop, @container_prop
    assert_equal @expected_container_props, prophash
  end

  def test_parse_propstats
    expected = [['200', nil, @expected_container_props]]
    assert_propstats expected, @container_response
  end

  def test_parse_propstats2
    expected = [['200', nil, @container2_200_props],
                ['401', nil, @container2_401_props],
                ['403', nil, @container2_403_props]]
    assert_propstats expected, @container2_response
  end

  def test_unauthorized
    assert !@response.unauthorized?
    assert @response2.unauthorized?
  end
   
end
