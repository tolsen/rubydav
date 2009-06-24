require 'rexml/document'

require 'test/unit/unit_test_helper'

class PropertyResultTestCase < RubyDavUnitTestCase

  class TestClass; end
  
  def setup
    super
    displayname_str = "<D:displayname xmlns:D='DAV:'>Bob</D:displayname>"
    @displayname_element = REXML::Document.new(displayname_str).root
    @displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    @result =
      RubyDav::PropertyResult.new @displayname_pk, '200', @displayname_element

    @error_result = RubyDav::PropertyResult.new @displayname_pk, '404', nil, :error

    @result208 =
      RubyDav::PropertyResult.new @displayname_pk, '208', @displayname_element

    @test_pk = RubyDav::PropKey.get 'DAV:', 'test'
    RubyDav::PropertyResult.define_class_reader :test_reader, TestClass, 'test'
  end

  def test_define_class_reader
    flexmock(TestClass).should_receive(:from_elem).with(:elem).
      once.and_return(:obj)
    result = RubyDav::PropertyResult.new @test_pk, '200', :elem
    assert_equal :obj, result.test_reader
  end

  def test_define_class_reader__raise_argument_error
    flexmock(TestClass).should_receive(:from_elem).with(:elem).
      once.and_raise(ArgumentError)
    result = RubyDav::PropertyResult.new @test_pk, '200', :elem
    assert_raises(RubyDav::BadResponseError) { result.test_reader }
  end

  def test_define_class_reader__wrong_prop_key
    flexmock(TestClass).should_receive(:from_elem).never
    test1_pk = RubyDav::PropKey.get 'DAV:', 'test1'
    result = RubyDav::PropertyResult.new test1_pk, '200', :elem
    assert_nil result.test_reader
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
    assert @result208.success?
  end

  def test_value 
    assert_xml_matches @result.value do |xml|
      xml.xmlns! 'DAV:'
      xml.displayname 'Bob'
    end

    assert_nil @error_result.value
  end

end

    
