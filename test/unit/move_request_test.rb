require 'test/unit/unit_test_helper'

class MoveRequestTest < RubyDavUnitTestCase
  def setup
    super
    @srcurl = File.join(@host,"src")
    @desturl = File.join(@host,"dest")
    @srcpath = URI.parse(@srcurl).path
  end
  
  def test_move_request_validate
    mresponse = mock_response("201")
    overwrite = false

    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_move(req,overwrite)}).and_return(mresponse)
    end
    response = RubyDav::Request.new.move(@srcurl,@desturl,overwrite)
    assert_equal "201", response.status
    
    overwrite = true
    response = RubyDav::Request.new.move(@srcurl,@desturl,overwrite)
    assert_equal "201", response.status
  end
  
  def validate_move(request,overwrite)
    overwrite = (overwrite)? 'T':'F'
    
    (request.is_a?(Net::HTTP::Move)) && 
      (request.path == URI.parse(@srcurl).path) && 
      (request['overwrite'] == overwrite) &&
      (request['destination'] == @desturl)
  end

end
