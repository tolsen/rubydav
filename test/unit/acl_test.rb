require 'test/unit/unit_test_helper'

class AceTest < RubyDavUnitTestCase
  def setup
    super
    @ace =  create_ace :grant, :all, true, "write", "read"
    @owner_pk = RubyDav::PropKey.get 'DAV:', 'owner'
  end

#   def teardown
#     GC.start
#   end
  
  def test_create
    assert_not_nil @ace
  end
  
  def self.create_principal_tests *testcases
    testcases.each do |principal|
      define_method "test_ace_principal_#{principal.to_s}" do
        ace = create_ace :grant, principal, false, "write"
        principal = RubyDav::PropKey.strictly_prop_key principal if ((Symbol === principal) &&
                                                                     (principal != :all) &&
                                                                     (principal != :authenticated) &&
                                                                     (principal != :unauthenticated) &&
                                                                     (principal != :self))
        assert_equal principal, ace.principal
      end
    end
  end
  
  create_principal_tests(:all, :authenticated, :unauthenticated, :self, 
                         RubyDav::PropKey.get("DAV:","owner"), "http://www.example.org/users",
                         :owners)
  
  
  def self.create_action_tests *testcases
    testcases.each do |action|
      define_method "test_action_#{action.to_s}" do
        ace = create_ace action, :all, false, "write", "read"
        assert_equal action, ace.action
      end
    end
  end
  
  create_action_tests :grant, :deny
  
  def test_protected
    assert_equal true, @ace.protected?
  end
  
  def test_privileges
    assert_equal 2, @ace.privileges.size
    assert_equal [@write_priv, @read_priv], @ace.privileges
  end
  
  def test_equality
    newace = create_ace :grant, :all, true, "write", "read"
    assert @ace == newace
  end
  
  def test_equality_fail_action
    ace = create_ace :deny, :all, true, "write", "read"
    assert @ace != ace
  end
  
  def test_equality_fail_principal
    ace = create_ace :grant, :self, true, "write", "read"
    assert @ace != ace
  end
  
  def test_equality_fail_protected
    ace = create_ace :grant, :all, false, "write", "read"
    assert @ace != ace
  end
  
  def test_equality_fail_privileges
    ace = create_ace :grant, :all, true, "write"
    assert @ace != ace
  end
  
  def test_equality_fail_class
    if (RubyDav::Ace == @ace.class)
      ace = RubyDav::InheritedAce.new "http://www.example.org", :grant, :all, true, "write", "read"
    else
      ace = RubyDav::Ace.new :grant, :all, true, "write", "read"
    end
    assert @ace != ace
  end

  def test_equality__privileges_in_different_order
    newace = create_ace :grant, :all, true, "read", "write"
    assert @ace == newace
  end
    
  def test_compactable
    ace = create_ace :grant, :all, true, "read-acl"
    assert @ace.compactable?(ace) 
  end
  
  def test_compactable_fail_class
    if RubyDav::Ace == @ace.class
      ace = RubyDav::InheritedAce.new "http://www.example.org", :grant, :all, true, "read-acl"
    else
      ace = RubyDav::Ace.new :grant, :all, true, "read-acl"
    end
    assert !( @ace.compactable? ace )
  end
  
  def test_compactable_fail_principal
    ace = create_ace :grant, :self, true, "read-acl"
    assert !( @ace.compactable? ace )
  end
  
  def test_compactable_fail_action
    ace = create_ace :deny, :all, true, "read-acl"
    assert !( @ace.compactable? ace )
  end
  
  def test_compactable_fail_protected
    ace = create_ace :grant, :all, false, "read-acl"
    assert !( @ace.compactable? ace )
  end
  
  def test_addprivileges
    assert_equal 2, @ace.privileges.size
    assert_equal [@write_priv, @read_priv], @ace.privileges
    
    @ace.addprivileges([:"read-acl"])
    assert_equal 3, @ace.privileges.size
    assert_equal [@write_priv, @read_priv, @read_acl_priv], @ace.privileges
  end

  def test_from_elem__bad_action
    ace_str = <<EOS
<ace xmlns='DAV:'>
  <principal><href>foo</href></principal>
  <hi><privilege><read/></privilege></hi>
</ace>
EOS
    ace_elem = body_root_element ace_str
    assert_raises RuntimeError do
      RubyDav::Ace.from_elem ace_elem
    end
  end

  def test_from_elem__deny
    ace_str = <<EOS
<D:ace xmlns:D='DAV:'> 
  <D:principal> 
    <D:href>http://www.example.com/groups/mrktng</D:href> 
  </D:principal> 
  <D:deny> 
    <D:privilege><D:read/></D:privilege>
  </D:deny> 
</D:ace> 
EOS
    
    ace_elem = body_root_element ace_str
    ace = RubyDav::Ace.from_elem ace_elem
    assert_instance_of RubyDav::Ace, ace

    assert_instance_of String, ace.principal
    assert_equal 'http://www.example.com/groups/mrktng', ace.principal

    assert_equal :deny, ace.action
    assert_equal [RubyDav::PropKey.get('DAV:', 'read')], ace.privileges

    assert !ace.protected?
  end

  def test_from_elem__grant
    ace_str = <<EOS
<D:ace xmlns:D='DAV:'> 
  <D:principal> 
    <D:href
    >http://www.example.com/acl/groups/maintainers</D:href> 
  </D:principal>  
  <D:grant> 
    <D:privilege><D:read/></D:privilege> 
    <D:privilege><D:write/></D:privilege> 
  </D:grant> 
</D:ace> 
EOS
    ace_elem = body_root_element ace_str
    ace = RubyDav::Ace.from_elem ace_elem
    assert_instance_of RubyDav::Ace, ace
    
    assert_instance_of String, ace.principal
    assert_equal 'http://www.example.com/acl/groups/maintainers', ace.principal

    assert_equal :grant, ace.action
    expected_privs = [RubyDav::PropKey.get('DAV:', 'read'),
                      RubyDav::PropKey.get('DAV:', 'write')]
    
    assert_equal expected_privs.sort, ace.privileges.sort
    assert !ace.protected?
  end

  def test_from_elem__inherited
    ace_str = <<EOS
<D:ace xmlns:D='DAV:'> 
  <D:principal><D:all/></D:principal> 
  <D:grant> 
    <D:privilege><D:read/></D:privilege>
  </D:grant> 
  <D:inherited> 
    <D:href>http://www.example.com/top</D:href> 
  </D:inherited> 
</D:ace>
EOS
    
    ace_elem = body_root_element ace_str
    ace = RubyDav::Ace.from_elem ace_elem
    assert_instance_of RubyDav::InheritedAce, ace

    assert_instance_of Symbol, ace.principal
    assert_equal :all, ace.principal

    assert_equal :grant, ace.action
    assert_equal [RubyDav::PropKey.get('DAV:', 'read')], ace.privileges

    assert_equal 'http://www.example.com/top', ace.url
    assert !ace.protected?
  end

  def test_from_elem__missing_principal
    ace_str = <<EOS
<ace xmlns='DAV:'>
  <grant><privilege><read/></privilege></grant>
</ace>
EOS
    ace_elem = body_root_element ace_str
    assert_raises RuntimeError do
      RubyDav::Ace.from_elem ace_elem
    end
  end

  def test_from_elem__protected
    ace_str = <<EOS
<ace xmlns='DAV:'>
  <principal><property><owner/></property></principal>
  <grant><privilege><all/></privilege></grant>
  <protected/>
</ace>
EOS
    
    ace_elem = body_root_element ace_str
    ace = RubyDav::Ace.from_elem ace_elem
    assert_instance_of RubyDav::Ace, ace
    
    assert_instance_of RubyDav::PropKey, ace.principal
    assert_equal @owner_pk, ace.principal

    assert_equal :grant, ace.action

    assert_equal [RubyDav::PropKey.get('DAV:', 'all')], ace.privileges
    assert ace.protected?
  end

  def test_generalize_principal!
    ace = create_ace(:grant, 'http://neurofunk.limewire.com:8080/users/bits',
                     false, :'write-properties')
    assert_same ace, ace.generalize_principal!
    assert_equal '/users/bits', ace.principal
  end

  def test_generalize_principal__property
    ace = create_ace :grant, @owner_pk, true, :all
    assert_same ace, ace.generalize_principal!
    assert_equal @owner_pk, ace.principal
  end

  def test_hash
    # cannot test that hash values are different as there may be a collision
    ace2 = create_ace :grant, :all, true, "write", "read"
    assert_equal @ace.hash, ace2.hash
  end

  def test_parse_principal_element__all
    principal_str = "<principal xmlns='DAV:'><all/></principal>"
    principal_elem = body_root_element principal_str

    result = RubyDav::Ace.parse_principal_element principal_elem
    assert_instance_of Symbol, result
    assert_equal :all, result
  end

  def test_parse_principal_element__bad_principal
    principal_str = "<principal xmlns='DAV:'><foo/></principal>"
    principal_elem = body_root_element principal_str
    
    assert_raises RuntimeError do
      RubyDav::Ace.parse_principal_element principal_elem
    end
  end
  
  def test_parse_principal_element__href
    principal_str = "<principal xmlns='DAV:'><href>foo</href></principal>"
    principal_elem = body_root_element principal_str

    result = RubyDav::Ace.parse_principal_element principal_elem
    assert_instance_of String, result
    assert_equal 'foo', result
  end
  
  def test_parse_principal_element__property
    principal_str = "<principal xmlns='DAV:'><property><owner/></property></principal>"
    principal_elem = body_root_element principal_str

    result = RubyDav::Ace.parse_principal_element principal_elem
    assert_instance_of RubyDav::PropKey, result
    assert_equal @owner_pk, result
  end
  
  def create_ace action, principal, protected, *privileges
    RubyDav::Ace.new action, principal, protected, *privileges
  end
  
  def self.create_to_xml_principal_tests *testcases
    testcases.each do |principal|
      define_method "test_to_xml_ace_principal_#{principal.to_s}" do
        ace = create_ace :grant, principal, false, "write", "read"
        principal = RubyDav::PropKey.strictly_prop_key principal if ((Symbol === principal) &&
                                                                     (principal != :all) &&
                                                                     (principal != :authenticated) &&
                                                                     (principal != :unauthenticated) &&
                                                                     (principal != :self))

        assert_ace_xml ace, principal
      end
    end
  end
  
  create_to_xml_principal_tests(:all, :authenticated, :unauthenticated, :self, 
                                  RubyDav::PropKey.get("DAV:","owner"), "http://www.example.org/users",
                                  :owners)
  
  
  def self.create_to_xml_action_tests *testcases
    testcases.each do |action|
      define_method "test_to_xml_action_#{action.to_s}" do
        ace = create_ace action, :all, false, "write", "read"
        assert_ace_xml ace, :all, action
      end
    end
  end
  
  create_to_xml_action_tests :grant, :deny
  
  def test_to_xml_protected
    ace = create_ace :grant, :all, true, "write", "read"
    assert_ace_xml ace, :all
  end
  
  def test_to_xml
    assert_ace_xml @ace, :all
  end

  def test_normalize_privileges
    assert_equal([@read_priv, @write_priv],
                 RubyDav::Ace.normalize_privileges(@read_priv, @write_priv))
    assert_equal([@read_priv, @write_priv],
                 RubyDav::Ace.normalize_privileges(:read, :write))
    assert_equal([@read_priv, @write_priv],
                 RubyDav::Ace.normalize_privileges('read', 'write'))
    assert_equal([@read_priv, @write_priv],
                 RubyDav::Ace.normalize_privileges(@read_priv, :write))
  end

  def assert_ace_xml ace, principal, action = :grant

    assert_xml_matches ace.to_xml do |xml|
      xml.xmlns! 'DAV:'
      xml.ace do
        
        xml.principal do
          case principal
          when Symbol
            xml.send principal
          when RubyDav::PropKey
            xml.property do
              xml.xmlns! principal.ns
              xml.send principal.name
            end
          else
            xml.href principal.to_s
          end
        end

        xml.send action do
          xml.privilege { xml.write }
          xml.privilege { xml.read }
        end

        xml.inherited { xml.href "http://www.example.org" } if
          ace.is_a? RubyDav::InheritedAce
        
        xml.protected if ace.protected?
      end
    end
  end
  
  
end

class InheritedAceTest < AceTest
  def create_ace action, principal, protected, *privileges
    RubyDav::InheritedAce.new "http://www.example.org",  action, principal, protected, *privileges
  end
  
  def test_create_inherited_url
    assert_equal "http://www.example.org", @ace.url
  end
  
  def test_equality_fail_url
    ace = RubyDav::InheritedAce.new "http://www.example.org/dir", :grant, :all, true, "write", "read"
    assert @ace != ace
  end
  
  def test_compactable_fail_url
    ace = RubyDav::InheritedAce.new "http://www.example.org/dir", :grant, :all, true, "read-acl"
    assert !@ace.compactable?(ace)
  end
  
  def test_to_xml_inherited
    ace = create_ace :grant, :all, false, "write", "read"
    assert_ace_xml ace, :all
  end
  
  def test_to_xml_inherited_protected
    ace = create_ace :grant, :all, true, "write", "read"
    assert_ace_xml ace, :all
  end
  
  
end

class AclTest < RubyDavUnitTestCase
  def setup
    super

    acl_str = <<EOS
<D:acl xmlns:D='DAV:'> 
  <D:ace> 
    <D:principal> 
      <D:href
      >http://www.example.com/acl/groups/maintainers</D:href> 
    </D:principal>  
    <D:grant> 
      <D:privilege><D:write/></D:privilege> 
    </D:grant> 
  </D:ace> 
  <D:ace> 
    <D:principal> 
      <D:all/> 
    </D:principal> 
    <D:grant> 
      <D:privilege><D:read/></D:privilege>  
    </D:grant> 
  </D:ace> 
</D:acl> 
EOS
    @acl_elem = body_root_element acl_str
    
    @acl = RubyDav::Acl.new
    @ace = RubyDav::Ace.new :grant, :all, true, "read-acl"
    @iace = RubyDav::InheritedAce.new "http://www.example.org", :grant, :all, true, "read-acl"
    @acl2 = RubyDav::Acl[@ace, @iace]
  end

  def test_array
    assert_instance_of RubyDav::Acl, @acl2
    assert_equal 2, @acl2.size
    assert_equal @ace, @acl2[0]
    assert_equal @iace, @acl2[1]
  end

  def test_clone
    acl3 = @acl2.clone
    @acl2.push @ace
    assert_equal 3, @acl2.size
    
    # check that pushing onto @acl2 didn't inadvertently push onto acl3
    assert_equal 2, acl3.size
  end
  
  def test_create
    assert_instance_of RubyDav::Acl, @acl
  end

  def test_compact!
    @acl.compacting = false
    
    @acl << @ace
    @acl.unshift RubyDav::Ace.new(:grant, :authenticated, false, "read")
    @acl.unshift RubyDav::Ace.new(:grant, :authenticated, false, "write")
    @acl.unshift RubyDav::Ace.new(:deny, :authenticated, false, "bind")
    @acl.unshift RubyDav::Ace.new(:grant, :authenticated, false, "write-acl")

    @acl << RubyDav::Ace.new(:grant, :all, false, "read")
    @acl << RubyDav::Ace.new(:grant, :all, false, "write-properties")
    @acl << RubyDav::InheritedAce.new( "http://www.example.org/foo", :grant, :all, false, "write-acl" )
    @acl << RubyDav::Ace.new(:grant, :all, false, "write-content")

    @acl.compact!

    expected_acl = RubyDav::Acl.new
    expected_acl << RubyDav::Ace.new(:grant, :authenticated, false, "write-acl")
    expected_acl << RubyDav::Ace.new(:deny, :authenticated, false, "bind")
    expected_acl << RubyDav::Ace.new(:grant, :authenticated, false, "write", "read")
    expected_acl << RubyDav::Ace.new(:grant, :all, true, "read-acl")
    expected_acl << RubyDav::Ace.new(:grant, :all, false, "read", "write-properties")
    expected_acl << RubyDav::InheritedAce.new( "http://www.example.org/foo", :grant, :all, false, "write-acl" )
    expected_acl << RubyDav::Ace.new(:grant, :all, false, "write-content")

    assert_equal expected_acl, @acl
  end
  
  def test_compacting_true
    @acl.compacting= true
    assert @acl.compacting?
  end
  
  def test_compacting_false
    @acl.compacting= false
    assert !@acl.compacting?
  end
  
  def test_equality
    @acl.unshift @ace
    acl = RubyDav::Acl.new
    acl.unshift @ace
    
    assert @acl == acl
  end
  
  def test_equality2
    @acl.unshift @ace
    @acl.unshift @iace
    acl = RubyDav::Acl.new
    acl.unshift @ace
    acl.unshift @iace
    
    assert @acl == acl
  end
  
  def test_equality_fail_class
    assert @acl != @ace
  end
  
  def test_equality_fail_content
    @acl.unshift @ace
    acl = RubyDav::Acl.new
    acl.unshift @iace
    
    assert !(@acl == acl)
  end

  def test_from_elem
    acl = RubyDav::Acl.from_elem @acl_elem
    assert_instance_of RubyDav::Acl, acl

    expected_acl =
      RubyDav::Acl[
                   RubyDav::Ace.new(:grant,
                                    'http://www.example.com/acl/groups/maintainers',
                                    false, RubyDav::PropKey.get('DAV:', 'write')),
                   RubyDav::Ace.new(:grant, :all, false,
                                    RubyDav::PropKey.get('DAV:', 'read'))]
    assert_equal expected_acl, acl
  end

  def test_generalize_principals!
    expected_principals = ['/users/bits', '/users/chetan', :all]
    
    acl =
      RubyDav::Acl[RubyDav::Ace.new(:grant,
                                    'http://neurofunk.limewire.com:8080/users/bits',
                                    false, :'write-properties'),
                   RubyDav::Ace.new(:deny,
                                    'http://chetan.limewire.com/users/chetan',
                                    false, :all),
                   RubyDav::Ace.new(:grant, :all, false, :read)]

    assert_same acl, acl.generalize_principals!
    principals = acl.map { |a| a.principal }
    assert_equal expected_principals, principals
  end

  def test_hash
    acl2 = RubyDav::Acl.new
    ace2 = RubyDav::Ace.new :grant, :all, true, "read-acl"
    iace2 = RubyDav::InheritedAce.new "http://www.example.org", :grant, :all, true, "read-acl"
    acl3 = RubyDav::Acl[ace2, iace2]

    assert_equal @acl.hash, acl2.hash
    assert_equal @acl2.hash, acl3.hash
  end
  
  def test_unshift_with_compacting_true
    @acl.compacting= true
    @acl.unshift @ace
    ace =  RubyDav::Ace.new :grant, :all, true, "read"
    @acl.unshift ace
    
    assert_equal 1, @acl.size
    assert_equal [@read_priv, @read_acl_priv], @acl[0].privileges
  end
  
  def test_to_xml
    expected_body = create_acl_xml [:all, :grant, ["read-acl"], false, true]
    @acl.unshift @ace
    acl_xml = String.new
    xml = Builder::XmlMarkup.new(:indent => 2, :target => acl_xml)
    @acl.to_xml xml
    assert xml_equal?(expected_body, acl_xml)
  end
  
  def test_to_xml2
    expected_body = create_acl_xml([:all, :grant, ["read-acl"], true, true], 
                                   [:all, :grant, ["read-acl"], false, true])
    @acl.unshift @ace
    @acl.unshift @iace
    acl_xml = String.new
    xml = Builder::XmlMarkup.new(:indent => 2, :target => acl_xml)
    @acl.to_xml xml
    assert xml_equal?(expected_body, acl_xml)
  end

  def test_property_result_class_reader
    acl_result = RubyDav::PropertyResult.new @acl_pk, '200', @acl_elem
    assert_instance_of RubyDav::Acl, acl_result.acl
  end
    

  def test_unshift_with_compacting_true_and_inherited_ace
    @acl.compacting= true
    @acl.unshift @ace
    @acl.unshift @iace
    
    assert_equal 2, @acl.size
    assert_equal [@read_acl_priv], @acl[0].privileges
    assert_equal "http://www.example.org", @acl[0].url
    assert_equal [@read_acl_priv], @acl[1].privileges
  end
  
  def test_unshift_with_compacting_false
    @acl.compacting= false
    @acl.unshift @ace
    ace =  RubyDav::Ace.new :grant, :all, true, "read"
    @acl.unshift ace
    
    assert_equal 2, @acl.size
    assert_equal [@read_priv], @acl[0].privileges
    assert_equal [@read_acl_priv], @acl[1].privileges
  end

end
