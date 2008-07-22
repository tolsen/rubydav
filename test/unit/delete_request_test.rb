require 'test/unit/unit_test_helper'

class DeleteRequestTest < RubyDavUnitTestCase
  def setup
    super
    @url = File.join(@host,"myhome")
    @url_path = URI.parse(@url).path
  end
  
  def test_delete_request_validate
    mresponse = mock_response("204")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_delete(req)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.delete(@url)
    assert_equal(response.status,"204")
  end
  
  def validate_delete(request)
    (request.is_a?(Net::HTTP::Delete)) && (request.path == @url_path)
  end
end
