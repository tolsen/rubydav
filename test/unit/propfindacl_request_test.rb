require 'test/unit/unit_test_helper'

class PropfindAclRequestTest < RubyDavUnitTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @request_body = <<EOS
<?xml version="1.0" encoding="utf-8" ?>
<D:propfind xmlns:D="DAV:">
  <D:prop>
    <D:acl />
  </D:prop>
</D:propfind>
EOS
  end
  
  def self.create_request_validation_tests(*testcases)
    testcases.each do |depth|
      define_method "test_propfind_acl_request_depth_#{depth.to_s}" do
        mresponse = mock_response("403")
        flexstub(Net::HTTP).new_instances do |http|
          http.should_receive(:request).with(on { |req|
                                               validate_propfind_acl(req,depth.to_s.downcase,@request_body)
                                             }).and_return(mresponse)
        end
        response = RubyDav::Request.new.propfind_acl(@url,depth)
      end
    end
  end
  
  create_request_validation_tests RubyDav::INFINITY, 0, 1
  
  def validate_propfind_acl(request,depth,body)
    (request.is_a?(Net::HTTP::Propfind)) &&
      (request.path == URI.parse(@url).path) &&
      (request['depth'].downcase == depth.to_s) &&
      (normalized_rexml_equal(body, request.body_stream.read))
  end
  
  
end
