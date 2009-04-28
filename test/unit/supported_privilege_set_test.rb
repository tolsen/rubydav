require 'test/unit/unit_test_helper'

class SupportedPrivilegeTest < RubyDavUnitTestCase

  # creates a hash of privilege -> supported_privilege
  # for argument's children
  def spriv_child_hash supported_privilege
    supported_privilege.children.inject({}) { |h, c| h[c.privilege] = c; h }
  end
    
  def setup
    super
    @supported_privilege_elem =
      RubyDav::xpath_first @supported_privilege_set_elem, 'supported-privilege'

    @write_content_spriv =
      RubyDav::SupportedPrivilege.new @write_content_priv, 'write content', 'en'
    @write_properties_spriv =
      RubyDav::SupportedPrivilege.new(@write_properties_priv,
                                      'write properties', 'en', true)

    @write_spriv =
      RubyDav::SupportedPrivilege.new(@write_priv, 'write', 'en-US', false,
                                      @write_content_spriv,
                                      @write_properties_spriv)
  end

  def test_abstract
    assert !@write_content_spriv.abstract?
    assert @write_properties_spriv.abstract?
    assert !@write_spriv.abstract?
  end

  def test_from_elem
    spriv = RubyDav::SupportedPrivilege.from_elem @supported_privilege_elem
    
    assert_instance_of RubyDav::SupportedPrivilege, spriv
    assert_equal @all_priv, spriv.privilege
    assert_equal 'Any operation', spriv.description.strip
    assert spriv.abstract?
    
    sprivs = spriv_child_hash spriv
    # top-level keys tested in test_map_from_elem_to_children
    sprivs.values.each { |sp| assert !sp.abstract? }
    assert_equal 'Read any object', sprivs[@read_priv].description.strip
    assert_equal 'Write any object', sprivs[@write_priv].description.strip
    assert_equal 'Unlock resource', sprivs[@unlock_priv].description.strip

    read_sub_sprivs = spriv_child_hash sprivs[@read_priv]
    assert_equal([@read_acl_priv, @read_cups_priv].sort,
                 read_sub_sprivs.keys.sort)
    read_sub_sprivs.values.each { |sp| assert sp.abstract? }
    assert_equal 'Read ACL', read_sub_sprivs[@read_acl_priv].description.strip
    assert_equal('Read current user privilege set property',
                 read_sub_sprivs[@read_cups_priv].description.strip)

    write_sub_sprivs = spriv_child_hash sprivs[@write_priv]
    assert_equal([@write_acl_priv, @write_properties_priv,
                  @write_content_priv].sort,
                 write_sub_sprivs.keys.sort)
    assert write_sub_sprivs[@write_acl_priv].abstract?
    assert !write_sub_sprivs[@write_properties_priv].abstract?
    assert !write_sub_sprivs[@write_content_priv].abstract?
    assert_equal('Write ACL',
                 write_sub_sprivs[@write_acl_priv].description.strip)
    assert_equal('Write properties',
                 write_sub_sprivs[@write_properties_priv].description.strip)
    assert_equal('Write resource content',
                 write_sub_sprivs[@write_content_priv].description.strip)

    ([spriv] + sprivs.values + read_sub_sprivs.values +
     write_sub_sprivs.values).each do |sp|
      assert_equal 'en', sp.language
    end
    
  end

  def test_initialize
    assert_equal @write_content_priv, @write_content_spriv.privilege
    assert_equal 'write content', @write_content_spriv.description
    assert_equal 'en', @write_content_spriv.language
    assert_equal [], @write_content_spriv.children

    assert_equal @write_properties_priv, @write_properties_spriv.privilege
    assert_equal 'write properties', @write_properties_spriv.description
    assert_equal 'en', @write_properties_spriv.language
    assert_equal [], @write_properties_spriv.children

    assert_equal @write_priv, @write_spriv.privilege
    assert_equal 'write', @write_spriv.description
    assert_equal 'en-US', @write_spriv.language
    assert_equal([ @write_content_spriv, @write_properties_spriv ],
                 @write_spriv.children)
  end

  def test_map_from_elem_to_children
    child_sprivs =
      RubyDav::SupportedPrivilege.map_from_elem_to_children @supported_privilege_elem

    assert_equal([@read_priv, @write_priv, @unlock_priv].sort,
                 child_sprivs.map{ |sp| sp.privilege}.sort)
    child_sprivs.each do |sp|
      assert_instance_of RubyDav::SupportedPrivilege, sp
    end
  end

end

class SupportedPrivilegeSetTest < RubyDavUnitTestCase

  def setup
    super
    @set =
      RubyDav::SupportedPrivilegeSet.from_elem @supported_privilege_set_elem
  end
  
  def test_all_privileges
    expected_privileges =
      [ @read_priv, @read_cups_priv, @read_acl_priv,
        @write_priv, @write_acl_priv, @write_content_priv,
        @write_properties_priv, @all_priv, @unlock_priv ].sort

    assert_equal expected_privileges, @set.all_privileges.sort
  end

  def test_from_elem
    assert_instance_of RubyDav::SupportedPrivilegeSet, @set
    assert_equal 1, @set.supported_privileges.size
    assert_equal @all_priv, @set.supported_privileges[0].privilege
  end

  def test_initialize
    set = RubyDav::SupportedPrivilegeSet.new :priv1, :priv2
    assert_equal [:priv1, :priv2], set.supported_privileges
  end

  def test_property_result_class_reader
    sps_pk = RubyDav::PropKey.get 'DAV:', 'supported-privilege-set'
    sps_result = RubyDav::PropertyResult.new(sps_pk, '200',
                                             @supported_privilege_set_elem)
    assert_instance_of(RubyDav::SupportedPrivilegeSet,
                       sps_result.supported_privilege_set)
  end

end
