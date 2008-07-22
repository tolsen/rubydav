require 'test/response_builder'
require 'lib/rubydav/prop_key'
require 'lib/rubydav/acl'

module PropfindAclTestHelper
  def self.create_principal_tests(*testcases)
    testcases.each do |principal|
      define_method "test_propfindacl_response_for_principal_#{principal.to_s}" do
        validate_depth0_response [[nil, :grant, principal, false, "read", "write"]]
      end
    end
  end
  
  def self.create_action_tests(*testcases)
    testcases.each do |action|
      define_method "test_propfindacl_response_for_action_#{action.to_s}" do
        validate_depth0_response [[nil, action, :all, false, "read", "write"]]
      end
    end
  end
  
  def self.create_inherited_and_protected_tests(*testcases)
    testcases.each do |(inherited_url,protected)|
      define_method "test_propfindacl_response_for_inherited_#{inherited_url.to_s}_and_protected_#{protected.to_s}" do
        validate_depth0_response [[inherited_url, :grant, :all, protected, "read", "write"]]
      end
    end
  end

  
  create_principal_tests(:all, :authenticated, :unauthenticated,
                         :self, "http://www.example.org/users/user1",
                         RubyDav::PropKey.get("DAV:","owner"))
  
  create_action_tests :grant, :deny

  create_inherited_and_protected_tests [nil, true],["http://www.example.org", false],["http://www.example.org", true]

  def test_multiple_aces
    ace1 = ["http://www.example.org", :grant, :all, true, "read","write"]
    ace2 = [nil, :deny, :owner, true, "write"]
    ace3 = [nil, :grant, :self, false, "write-acl"]
    
    validate_depth0_response [ace1, ace2, ace3]
  end

  def validate_depth0_response params
    acl, protected_acl, inherited_acl, allacl = create_acl_lists params
    
    responsehash = {}
    responsehash["http://www.example.org/dir"] = ["200", nil, allacl]
    body = ResponseBuilder.new.construct_propfindacl_response(responsehash)
    
    response = get_response("http://www.example.org/dir",body)
    assert_propaclresponse_object(response, acl, protected_acl, 
                                  inherited_acl , "200", 0)
  end

  def test_depth_infinity
    ace = [nil, :grant, :self, false, "writeacl"]
    acl, protected_acl, inherited_acl, allacl = create_acl_lists [ace]
    
    responsehash = {}
    responsehash["http://www.example.org/dir"] = ["200", nil, allacl]
    responsehash["http://www.example.org/dir/dir1"] = ["200", nil, allacl]
    responsehash["http://www.example.org/dir/dir2"] = ["200", nil, allacl]
    responsehash["http://www.example.org/dir/dir1/subdir1"] = ["403",nil, []]
    
    body = ResponseBuilder.new.construct_propfindacl_response(responsehash)
    
    response = get_response("http://www.example.org/dir",body)
    assert_propaclresponse_object(response, acl, protected_acl, inherited_acl , "200", 2)
    
    response1 = response.children["dir1"]
    assert_propaclresponse_object(response1, acl, protected_acl, inherited_acl , "200", 1)
    
    response2 = response.children["dir2"]
    assert_propaclresponse_object(response2, acl, protected_acl, inherited_acl , "200", 0)
    
    response3 = response1.children["subdir1"]
    assert_propaclresponse_object(response3, [], [], [], "403", 0)
  end

  def assert_propaclresponse_object(response, acl, protected_acl, inherited_acl, acl_status, num_of_children)
    assert_instance_of(RubyDav::PropfindAclResponse, response)
    assert_equal(num_of_children, response.children.length)
    
    assert_equal acl, response.acl
    assert_equal protected_acl, response.protected_acl
    assert_equal inherited_acl, response.inherited_acl
    assert_equal acl_status, response.acl_status
  end
end
