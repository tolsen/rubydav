require 'test/unit/unit_test_helper'

class AceTest < RubyDavUnitTestCase
  def setup
    @ace =  create_ace :grant, :all, true, "write", "read"
  end
  
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
    assert_equal [:write,:read], @ace.privileges
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
    assert_equal [:write,:read], @ace.privileges
    
    @ace.addprivileges([:"read-acl"])
    assert_equal 3, @ace.privileges.size
    assert_equal [:write,:read,:"read-acl"], @ace.privileges
  end
  
  def create_ace action, principal, protected, *privileges
    RubyDav::Ace.new action, principal, protected, *privileges
  end
  
  def self.create_printXML_principal_tests *testcases
    testcases.each do |principal|
      define_method "test_printXML_ace_principal_#{principal.to_s}" do
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
  
  create_printXML_principal_tests(:all, :authenticated, :unauthenticated, :self, 
                                  RubyDav::PropKey.get("DAV:","owner"), "http://www.example.org/users",
                                  :owners)
  
  
  def self.create_printXML_action_tests *testcases
    testcases.each do |action|
      define_method "test_printXML_action_#{action.to_s}" do
        ace = create_ace action, :all, false, "write", "read"
        assert_ace_xml ace, :all, action
      end
    end
  end
  
  create_printXML_action_tests :grant, :deny
  
  def test_printXML_protected
    ace = create_ace :grant, :all, true, "write", "read"
    assert_ace_xml ace, :all
  end
  
  def test_printXML
    assert_ace_xml @ace, :all
  end

  def assert_ace_xml ace, principal, action = :grant

    assert_xml_matches ace.printXML do |xml|
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
  
  def test_printXML_inherited
    ace = create_ace :grant, :all, false, "write", "read"
    assert_ace_xml ace, :all
  end
  
  def test_printXML_inherited_protected
    ace = create_ace :grant, :all, true, "write", "read"
    assert_ace_xml ace, :all
  end
  
  
end

class AclTest < RubyDavUnitTestCase
  def setup
    @acl = RubyDav::Acl.new
    @ace = RubyDav::Ace.new :grant, :all, true, "read-acl"
    @iace = RubyDav::InheritedAce.new "http://www.example.org", :grant, :all, true, "read-acl"
  end
  
  def test_create
    assert_not_nil @acl
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
  
  def test_unshift_with_compacting_true
    @acl.compacting= true
    @acl.unshift @ace
    ace =  RubyDav::Ace.new :grant, :all, true, "read"
    @acl.unshift ace
    
    assert_equal 1, @acl.size
    assert_equal [:read,:"read-acl"], @acl[0].privileges
  end
  
  def test_unshift_with_compacting_true_and_inherited_ace
    @acl.compacting= true
    @acl.unshift @ace
    @acl.unshift @iace
    
    assert_equal 2, @acl.size
    assert_equal [:"read-acl"], @acl[0].privileges
    assert_equal "http://www.example.org", @acl[0].url
    assert_equal [:"read-acl"], @acl[1].privileges
  end
  
  def test_unshift_with_compacting_false
    @acl.compacting= false
    @acl.unshift @ace
    ace =  RubyDav::Ace.new :grant, :all, true, "read"
    @acl.unshift ace
    
    assert_equal 2, @acl.size
    assert_equal [:read], @acl[0].privileges
    assert_equal [:"read-acl"], @acl[1].privileges
  end
  
  def test_printXML
    expected_body = create_acl_xml [:all, :grant, ["read-acl"], false, true]
    @acl.unshift @ace
    acl_xml = String.new
    xml = Builder::XmlMarkup.new(:indent => 2, :target => acl_xml)
    @acl.printXML xml
    assert (normalized_rexml_equal expected_body, acl_xml)
  end
  
  def test_printXML2
    expected_body = create_acl_xml([:all, :grant, ["read-acl"], true, true], 
                                   [:all, :grant, ["read-acl"], false, true])
    @acl.unshift @ace
    @acl.unshift @iace
    acl_xml = String.new
    xml = Builder::XmlMarkup.new(:indent => 2, :target => acl_xml)
    @acl.printXML xml
    assert (normalized_rexml_equal expected_body, acl_xml)
  end

end
