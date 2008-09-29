require 'test/unit/unit_test_helper'

class ProppatchRequestTest < RubyDavUnitTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  def test_proppatch_request
    # Note: Incomplete
    body = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<D:propertyupdate xmlns:D="DAV:">
  <D:set>
    <D:prop>
      <R:properties xmlns:R="http://www.example.org/namespace">
        <R:author1>name1</R:author1>
        <R:author2>name2</R:author2>
      </R:properties>
    </D:prop>
  </D:set>
  <D:remove>
    <D:prop>
      <D:property2/>
    </D:prop>
  </D:remove>
</D:propertyupdate>
EOS
    mresponse = mock_response("404")
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_proppatch(req,body)}).and_return(mresponse)
    end
    
    propkey= RubyDav::PropKey.get("http://www.example.org/namespace","properties") 
    props = {}
    valxml = Builder::XmlMarkup.new(:indent => 2)
    valxml.R(:author1, "name1")
    valxml.R(:author2, "name2")
    props[propkey]= valxml
    props[:property2]= :remove
    
    response = RubyDav::Request.new.proppatch(@url,props)
    assert_equal(response.status,"404")
  end
  
  def validate_proppatch(request,body)
    (request.is_a?(Net::HTTP::Proppatch)) &&
      (request.path == @url_path) &&
      (normalized_rexml_equal(body,request.body_stream.read))
  end
  
end
