require 'rexml/document'

require 'test/unit/unit_test_helper'

class PropertyResultTestCase < Test::Unit::TestCase

  def setup
    displayname_str = "<D:displayname xmlns:D='DAV:'>Bob</D:displayname>"
    displayname_element = REXML::Document.new(displayname_str).root
    @displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    @result =
      RubyDav::PropertyResult.new @displayname_pk, '200', displayname_element

    @error_result = RubyDav::PropertyResult.new @displayname_pk, '404', nil, :error
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

  def test_value 
    assert_xml_matches @result.value do |xml|
      xml.xmlns! 'DAV:'
      xml.displayname 'Bob'
    end

    assert_nil @error_result.value
  end

end

    
