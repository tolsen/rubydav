# $URL$
# $Id$

require 'test/test_helper'

class IfHeaderTestCase < Test::Unit::TestCase

  include RubyDav
  
  def setup
    @etag = '"STRONGETAG"'
    @locktoken = "urn:uuid:f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
    @url = "http://www.example.com/resource"

    @etag2 = '"STRONGETAG2"'
    @locktoken2 = "urn:uuid:150852e2-3847-42d5-8cbe-0f4f296f26cf"
    @url2 = "http://www.example.com/resource2"

    @etag3 = 'W/"WEAKETAG3"'
    @locktoken3 = "urn:uuid:fe184f2e-6eec-41d0-c765-01adc56e6bb4"

    @etag4 = '"STRONGETAG4"'
    @locktoken4 = "urn:uuid:e454f3f3-acdc-452a-56c7-00a5c91e4b77"
 
  end
  
  def test_tokenize_strong_etag
    assert_equal "[#{@etag}]", IfHeader.tokenize(@etag)
  end

  def test_tokenize_weak_etag
    assert_equal '[W/"WEAKETAG"]', IfHeader.tokenize('W/"WEAKETAG"')
  end

  def test_tokenize_locktoken
    assert_equal("<#{@locktoken}>", IfHeader.tokenize(@locktoken))
    assert_equal("<opaquelocktoken:f81d4fae-7dec-11d0-a765-00a0c91e6bf6>",
                 IfHeader.tokenize("opaquelocktoken:f81d4fae-7dec-11d0-a765-00a0c91e6bf6"))
  end

  def test_if_header_single_untagged_token
    assert_equal "([#{@etag}])", IfHeader.if_header(true, @etag)
    assert_equal "(<#{@locktoken}>)", IfHeader.if_header(true, @locktoken)
  end

  def test_if_header_multiple_untagged_tokens
    assert_equal "([#{@etag}] <#{@locktoken}>)", IfHeader.if_header(true, @etag, @locktoken)
  end

  def test_if_header_multiple_or_untagged_tokens
    assert_equal("([#{@etag}] <#{@locktoken}>) ([#{@etag2}] <#{@locktoken2}>)",
                 IfHeader.if_header(true, [@etag, @locktoken], [@etag2, @locktoken2]))
  end

  def test_if_header_multiple_or_untagged_tokens_inside_one_array
    assert_equal("([#{@etag}] <#{@locktoken}>) ([#{@etag2}] <#{@locktoken2}>)",
                 IfHeader.if_header(true, [ [@etag, @locktoken], [@etag2, @locktoken2] ]))
  end
  
  def test_if_header_single_tagged_token
    assert_equal "<#{@url}> ([#{@etag}])", IfHeader.if_header(true, @url => @etag)
  end

  def test_if_header_multiple_tokens_single_tag
    assert_equal("<#{@url}> ([#{@etag}] <#{@locktoken}>)",
                 IfHeader.if_header(true, @url => [@etag, @locktoken]))
  end

  def test_if_header_multiple_tags_each_with_one_token
    assert_tagged_if_header(IfHeader.if_header(true, @url => @etag, @url2 => @locktoken2),
                            "<#{@url}> ([#{@etag}])", "<#{@url2}> (<#{@locktoken2}>)")

  end

  def test_if_header_multiple_tags_multiple_tokens
    assert_tagged_if_header(IfHeader.if_header(true,
                                               @url => [@etag, @locktoken],
                                               @url2 => [@locktoken2, @etag2]),
                            "<#{@url}> ([#{@etag}] <#{@locktoken}>)",
                            "<#{@url2}> (<#{@locktoken2}> [#{@etag2}])")
  end

  def test_if_header_multiple_tags_multiple_or_tokens
    assert_tagged_if_header(IfHeader.if_header(true,
                                               @url => [[@locktoken, @etag],
                                                        [@etag3, @locktoken3]],
                                               @url2 => [[@locktoken4, @etag4],
                                                         [@etag2, @locktoken2]]),
                            "<#{@url}> (<#{@locktoken}> [#{@etag}]) ([#{@etag3}] <#{@locktoken3}>)",
                            "<#{@url2}> (<#{@locktoken4}> [#{@etag4}]) ([#{@etag2}] <#{@locktoken2}>)")
  end

  def test_if_header_nonstrict_single_untagged_token
    assert_equal "([#{@etag}]) (Not <DAV:nolock>)", IfHeader.if_header(false, @etag)
    assert_equal "(<#{@locktoken}>) (Not <DAV:nolock>)", IfHeader.if_header(false, @locktoken)
  end

  def test_if_header_nonstrict_multiple_untagged_tokens
    assert_equal "([#{@etag}] <#{@locktoken}>) (Not <DAV:nolock>)", IfHeader.if_header(false, @etag, @locktoken)
  end

  def test_if_header_nonstrict_multiple_or_untagged_tokens
    assert_equal("([#{@etag}] <#{@locktoken}>) ([#{@etag2}] <#{@locktoken2}>) (Not <DAV:nolock>)",
                 IfHeader.if_header(false, [@etag, @locktoken], [@etag2, @locktoken2]))
  end
  
  def test_if_header_nonstrict_single_tagged_token
    assert_equal "<#{@url}> ([#{@etag}]) (Not <DAV:nolock>)", IfHeader.if_header(false, @url => @etag)
  end

  def test_if_header_nonstrict_multiple_tokens_single_tag
    assert_equal("<#{@url}> ([#{@etag}] <#{@locktoken}>) (Not <DAV:nolock>)",
                 IfHeader.if_header(false, @url => [@etag, @locktoken]))
  end

  def test_if_header_nonstrict_multiple_tags_each_with_one_token
    assert_tagged_if_header(IfHeader.if_header(false, @url => @etag, @url2 => @locktoken2),
                            "<#{@url}> ([#{@etag}]) (Not <DAV:nolock>)",
                            "<#{@url2}> (<#{@locktoken2}>) (Not <DAV:nolock>)")

  end

  def test_if_header_nonstrict_multiple_tags_multiple_tokens
    assert_tagged_if_header(IfHeader.if_header(false,
                                               @url => [@etag, @locktoken],
                                               @url2 => [@locktoken2, @etag2]),
                            "<#{@url}> ([#{@etag}] <#{@locktoken}>) (Not <DAV:nolock>)",
                            "<#{@url2}> (<#{@locktoken2}> [#{@etag2}]) (Not <DAV:nolock>)")
  end

  def test_if_header_nonstrict_multiple_tags_multiple_or_tokens
    assert_tagged_if_header(IfHeader.if_header(false,
                                               @url => [[@locktoken, @etag],
                                                        [@etag3, @locktoken3]],
                                               @url2 => [[@locktoken4, @etag4],
                                                         [@etag2, @locktoken2]]),
                            "<#{@url}> (<#{@locktoken}> [#{@etag}]) ([#{@etag3}] <#{@locktoken3}>) (Not <DAV:nolock>)",
                            "<#{@url2}> (<#{@locktoken4}> [#{@etag4}]) ([#{@etag2}] <#{@locktoken2}>) (Not <DAV:nolock>)")
  end


  def assert_tagged_if_header actual, *expected
    expected.each do |e|
      assert actual.include?(e)
    end

    expected_size = expected.inject(0) { |sum, e| sum + e.count('^ ') }
    assert_equal actual.count('^ '), expected_size
  end
  
    
end
