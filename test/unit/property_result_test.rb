require 'rexml/document'

require 'test/unit/unit_test_helper'

class PropertyResultTestCase < RubyDavUnitTestCase

  def setup
    super
    displayname_str = "<D:displayname xmlns:D='DAV:'>Bob</D:displayname>"
    @displayname_element = REXML::Document.new(displayname_str).root
    @displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    @result =
      RubyDav::PropertyResult.new @displayname_pk, '200', @displayname_element

    @error_result = RubyDav::PropertyResult.new @displayname_pk, '404', nil, :error

    @acl_pk = RubyDav::PropKey.get 'DAV:', 'acl'
  end

  def test_acl
    @acl_result = RubyDav::PropertyResult.new @acl_pk, '200', @acl_elem
    assert_instance_of RubyDav::Acl, @acl_result.acl
  end

  def test_acl__not_an_acl
    assert_nil @result.acl
  end

  def test_current_user_privilege_set
    cups_pk = RubyDav::PropKey.get 'DAV:', 'current-user-privilege-set'
    cups_result = RubyDav::PropertyResult.new cups_pk, '200', @cups_elem
    assert_instance_of(RubyDav::CurrentUserPrivilegeSet,
                       cups_result.current_user_privilege_set)
    assert_instance_of RubyDav::CurrentUserPrivilegeSet, cups_result.cups
  end

  def test_current_user_privilege_set__not_cups
    assert_nil @result.current_user_privilege_set
  end

  def test_eql
    # not sure which object has eql? called on it
    # so I'm testing it in both directions
    assert_not_equal @displayname_pk, @result
    assert_not_equal @result, @displayname_pk

    assert_not_equal @error_result, @result

    expected =
      RubyDav::PropertyResult.new @displayname_pk, '200', @displayname_element
    assert_equal expected, @result
  end

  def test_initialize
    assert_equal @displayname_pk, @result.prop_key
    assert_equal '200', @result.status
    assert_equal 'DAV:', @result.element.namespace
    assert_equal 'displayname', @result.element.name
    assert_equal 'Bob', @result.element.text.strip
    assert_nil @result.error

    assert_equal @displayname_pk, @error_result.prop_key
    assert_equal '404', @error_result.status
    assert_nil @error_result.element
    assert_equal :error, @error_result.error
  end

  def test_inner_value
    assert_equal 'Bob', @result.inner_value.strip

    assert_nil @error_result.inner_value
  end

  def test_success
    assert @result.success?
    assert !@error_result.success?
  end

  def test_supported_privilege_set
    sps_pk = RubyDav::PropKey.get 'DAV:', 'supported-privilege-set'
    sps_result = RubyDav::PropertyResult.new(sps_pk, '200',
                                             @supported_privilege_set_elem)
    assert_instance_of(RubyDav::SupportedPrivilegeSet,
                       sps_result.supported_privilege_set)
  end
  
  def test_supported_privilege_set__not_an_sps
    assert_nil @result.supported_privilege_set
  end

  def test_value 
    assert_xml_matches @result.value do |xml|
      xml.xmlns! 'DAV:'
      xml.displayname 'Bob'
    end

    assert_nil @error_result.value
  end

end

    
