require 'test/unit/unit_test_helper'

class PropfindRequestTest < RubyDavUnitTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  def test_propfind_allprop_request
    body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:allprop/>
</D:propfind>
EOS
    mresponse = mock_response("403")
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_propfind(req,RubyDav::INFINITY,body)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url,RubyDav::INFINITY,:allprop)
    assert_equal(response.status,"403")
  end
  
  def test_propfind_allprop_include_request
    body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:allprop/>
  <D:include>
    <D:acl/>
    <D:resource-id/>
  </D:include>
</D:propfind>
EOS
    mresponse = mock_response("403")
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_propfind(req,RubyDav::INFINITY,body)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url,RubyDav::INFINITY,:allprop,
                                             :acl,:'resource-id')
    assert_equal(response.status,"403")
  end
  
  def test_propfind_propname_request
    body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:propname/>
</D:propfind>
EOS
    mresponse = mock_response("403")
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_propfind(req,RubyDav::INFINITY,body)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url,RubyDav::INFINITY,:propname)
    assert_equal(response.status,"403")
  end
  
  def test_propfind_prop_request
    body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:displayname/>
    <R:author xmlns:R="www.example.org/mynamespace"/>
    <D:getcontentlength/>
  </D:prop>
</D:propfind>
EOS
    mresponse = mock_response("403")
    
    props = []
    props << :displayname
    props << RubyDav::PropKey.get("www.example.org/mynamespace",'author')
    props << RubyDav::PropKey.get("DAV:","getcontentlength")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_propfind(req,RubyDav::INFINITY,body)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url,RubyDav::INFINITY,*props)
    assert_equal(response.status,"403")
  end

  def test_propfind_unauthorized_propstat
    expected_body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:displayname/>
  </D:prop>
</D:propfind>
EOS

    response = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/</D:href>
    <D:propstat>
      <D:prop><D:displayname>Root Collection</D:displayname></D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
  <D:response>
    <D:href>/private</D:href>
    <D:propstat>
      <D:prop><D:displayname/></D:prop>
      <D:status>HTTP/1.1 401 Unauthorized</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>
EOS
    mresponse = mock_response 207, response

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on do |req|
                                           validate_propfind(req,
                                                             RubyDav::INFINITY,
                                                             expected_body)
                                         end).and_return(mresponse)
    end
    response = RubyDav::Request.new.propfind(@url,RubyDav::INFINITY, :displayname)
    assert_equal '207', response.status
    assert response.unauthorized?
  end
  


  def self.create_request_validation_tests(*testcases)
    testcases.each do |depth|
      define_method "test_propfind_request_depth_#{depth.to_s}" do
        body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:allprop/>
</D:propfind>
EOS
        mresponse = mock_response("404")
        flexstub(Net::HTTP).new_instances do |http|
          http.should_receive(:request).with(on {|req| validate_propfind(req,depth,body)}).and_return(mresponse)
        end
        response = RubyDav::Request.new.propfind(@url,depth,:allprop)
      end
    end
  end
  
  create_request_validation_tests RubyDav::INFINITY,0,1
    
end
