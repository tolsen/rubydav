require 'test/unit/unit_test_helper'

class CopyRequestTest < RubyDavUnitTestCase
  def setup
    super
    @srcurl = File.join(@host,"src")
    @desturl = File.join(@host,"dest")
    @src_path = URI.parse(@srcurl).path
  end

  def self.create_request_validation_tests(testcases)
    testcases.each do |parameters|
      define_method "test_copy_request_depth_#{parameters[0]}_overwrite_#{parameters[1]}" do 
        mresponse = mock_response("201")
        flexstub(Net::HTTP).new_instances do |http|
          http.should_receive(:request).with(on {|req| validate_copy(req,parameters[0],parameters[1])}).and_return(mresponse)
        end
        response = RubyDav::Request.new.copy(@srcurl,@desturl,parameters[0],parameters[1])
      end
    end
  end
  
  create_request_validation_tests [[RubyDav::INFINITY,true],[RubyDav::INFINITY,false],["0",true],["0",false]]
  
  def validate_copy(request,depth,overwrite)
    overwrite = (overwrite)? "T":"F"
    depth = depth.to_s.downcase
    
    (request.is_a?(Net::HTTP::Copy)) && 
      (request.path == URI.parse(@srcurl).path) && 
      (request['overwrite'] == overwrite) &&
      (request['destination'] == @desturl) &&
      (request['depth'] == depth)
  end
  
  
end
