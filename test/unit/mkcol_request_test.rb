require 'test/unit/unit_test_helper'

class MkcolRequestTest < RubyDavUnitTestCase
  def setup
    super
    @collection_url = File.join(@host,"coll1")
    @coll_path = URI.parse(@collection_url).path
  end
  
  def test_mkcol_request_validate
    mresponse = mock_response("201")
    
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_mkcol(req)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.mkcol(@collection_url)
    assert_equal(response.status,"201")
  end
  
  def validate_mkcol(request)
    (request.is_a?(Net::HTTP::Mkcol)) && (request.path == @coll_path)
  end
  
end
