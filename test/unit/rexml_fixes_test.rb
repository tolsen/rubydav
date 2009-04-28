require 'test/unit/unit_test_helper'

class RexmlFixesTest < Test::Unit::TestCase

  def test_to_s_with_ns
    doc = '<D:displayname xmlns:D="DAV:">Bob</D:displayname>'
    root = REXML::Document.new(doc).root
    doc2 = root.to_s_with_ns

    assert_xml_matches doc2 do |xml|
      xml.xmlns! 'DAV:'
      xml.displayname 'Bob'
    end
  end

  # more tests needed
  
end
