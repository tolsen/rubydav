require 'test/unit/unit_test_helper'

class AclRequestTest < RubyDavUnitTestCase
  def setup
    super
    @host_path = URI.parse(@host).path
  end
  
  def self.create_acl_action_test *testcases
    testcases.each do |action|
      define_method "test_acl_action_#{action.to_s}" do
        body = create_acl_body [:all, action, ["write", "read"], false, false]
        acl = RubyDav::Acl.new
        acl << RubyDav::Ace.new(action, :all, false, "write", "read")
        send_acl_request_and_validate(acl,body)
      end
    end
  end
  
  create_acl_action_test :grant, :deny
  
  def test_acl_grant_deny
    body = create_acl_body([:authenticated, :grant, ["write", "read"], false, false], 
                           [:unauthenticated, :deny, ["write", "read"], false, false])
    acl = RubyDav::Acl.new
    acl << RubyDav::Ace.new(:grant, :authenticated, false, "write", "read")
    acl << RubyDav::Ace.new(:deny, :unauthenticated, false, "write", "read")
    
    send_acl_request_and_validate(acl,body)
  end
  
  def test_acl_inherited_protected_privilege
    body = create_acl_body [:all, :grant, ["write", "read"], true, true]
    acl = RubyDav::Acl.new
    acl << RubyDav::InheritedAce.new("http://www.example.org",:grant, :all, 
                                     true, "write", "read")
    send_acl_request_and_validate(acl)
  end
  
  
  def test_acl_inherited_privilege
    body = create_acl_body [:all, :grant, ["write", "read"], true, false]
    acl = RubyDav::Acl.new
    acl << RubyDav::InheritedAce.new("http://www.example.org",:grant, :all, 
                                     false, "write", "read")
    send_acl_request_and_validate(acl)
  end
  
  def test_acl_protected_privilege
    body = create_acl_body ["http://www.example.org/users/user1", :grant, ["write", "read"], false, true]
    acl = RubyDav::Acl.new
    acl << RubyDav::Ace.new(:grant, "http://www.example.org/users/user1", 
                            true, "write", "read")
    send_acl_request_and_validate(acl)
  end
  
  def self.create_acl_principal_test *testcases
    testcases.each do |principal|
      define_method "test_acl_principal_#{principal.to_s}" do
        body = create_acl_body [principal, :grant, ["write", "read"], false, false]
        acl = RubyDav::Acl.new
        acl << RubyDav::Ace.new(:grant, principal, false, "write", "read")
        send_acl_request_and_validate(acl,body)
      end
    end
  end
  
  create_acl_principal_test(:self, :all, :authenticated, :unauthenticated,
                            RubyDav::PropKey.get("DAV:","owner"), 
                            "http://www.example.org/users/", :owner)
  
  
  def validate_acl(request,body)
    (request.is_a?(Net::HTTP::Acl)) && 
      (request.path == @host_path) && 
      (body.nil? || xml_equal?(body,request.body_stream.read))
  end

  # body=nil skips request.body validation, only headers are verified,
  # required for ACLs containing protected/inherited ACEs,
  # which are omitted when sending an ACL request,
  # thus causing body to be different from request.body
  def send_acl_request_and_validate(acl, body=nil)
    mresponse = mock_response("200","Successful")
    flexstub(Net::HTTP).new_instances do |http|
      http.should_receive(:request).with(on {|req| validate_acl(req,body)}).and_return(mresponse)
    end
    request = RubyDav::Request.new
    request.acl(@host,acl)
  end
end
