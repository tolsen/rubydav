require 'test/unit/unit_test_helper'

class GetRequestTest < RubyDavUnitTestCase
  def setup
    super
    @body = "test body"
  end

  def test_get_request_validate
    mresponse = mock_response("200",@body)

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_get(req)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.get(@host)
    assert_equal(response.body,@body)
  end
  
end
