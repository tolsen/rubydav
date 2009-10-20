require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'
require 'lib/rubydav/search_helper'

class WebDavSearchTest < Test::Unit::TestCase
  include WebDavTestSetup
  include SearchHelper
  def setup
    webdavtestsetup
    generate_ops
  end

  def test_search_simple
    put_file_w_size 'file', 64

    where = eq(:getcontentlength, 64)
    scope = { homepath => :infinity }

    response = @request.search('', scope , where, :allprop)
    
    # search should return 1 result
    assert_num_search_results 1, response

    # the result must contain file
    fileresponse = response[homepath + 'file']
    assert_not_nil fileresponse

    # property getcontentlength must've been reported
    assert_equal 64, fileresponse[:getcontentlength].inner_value.to_i

    # cleanup
    delete_file 'file'
  end

  def test_search_resource_id
    new_coll 'test-search-resource-id'
    put_file_w_size 'test-search-resource-id/file', 64

    where = _not(is_collection)
    scope = { homepath + 'test-search-resource-id' => 1 }

    response = @request.search('', scope, where, :'resource-id')
    assert_equal '207', response.status

    # search should return 1 result
    assert_num_search_results 1, response

    # result must contain file
    fileresponse = response[homepath + 'test-search-resource-id/file']
    assert_not_nil fileresponse

    # property resource-id must've been reported
    assert_not_nil fileresponse[:'resource-id']

    # cleanup
    delete_coll 'test-search-resource-id'
  end

  def test_dead_prop_search
    file1 = 'file1'
    file2 = 'file2'
    file3 = 'file3'

    new_file file1, StringIO.new("file1")
    new_file file2, StringIO.new("file2")
    new_file file3, StringIO.new("file3")

    tag_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'tag')
    response = @request.proppatch(file1, { tag_pkey => 'interesting' })
    assert_equal '207', response.status

    response = @request.proppatch(file2, { tag_pkey => 'boring' })
    assert_equal '207', response.status

    response = @request.proppatch(file3, { tag_pkey => 'interesting' })
    assert_equal '207', response.status

    # search for file(s) with 'interesting' tag
    where = eq(tag_pkey, 'interesting')
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, tag_pkey)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got both file1 and file3
    file1response = response[homepath + 'file1']
    file3response = response[homepath + 'file3']
    assert_not_nil file1response
    assert_not_nil file3response

    # dead property tag must've been reported as 'interesting'
    assert_equal 'interesting', file1response[tag_pkey].inner_value
    assert_equal 'interesting', file3response[tag_pkey].inner_value

    # cleanup
    delete_file file1
    delete_file file2
    delete_file file3
  end

  def test_search_partial_matching
    file1 = 'file1'
    file2 = 'file2'
    file3 = 'file3'

    new_file file1, StringIO.new("file1")
    new_file file2, StringIO.new("file2")
    new_file file3, StringIO.new("file3")

    rating_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'rating')
    response = @request.proppatch(file1, { rating_pkey => 'a' })
    assert_equal '207', response.status

    response = @request.proppatch(file2, { rating_pkey => 'aa' })
    assert_equal '207', response.status

    response = @request.proppatch(file3, { rating_pkey => 'aab' })
    assert_equal '207', response.status

    # search for files with at least aa rating
    where = like(rating_pkey, 'aa%')
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, rating_pkey)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got file2 and file3
    assert_not_nil response[homepath + 'file2']
    assert_not_nil response[homepath + 'file3']

    # search for files with more than aa rating
    where = like(rating_pkey, 'aa_')
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, rating_pkey)

    # search should return 1 result
    assert_num_search_results 1, response

    # make sure we got file3
    assert_not_nil response[homepath + 'file3']

    # cleanup
    delete_file file1
    delete_file file2
    delete_file file3
  end

  def test_search_is_collection
    new_coll 'testsearch'
    file1 = 'testsearch/file1'
    coll1 = 'testsearch/coll1'
    coll2 = 'testsearch/coll1/coll2'

    new_file file1
    new_coll coll1
    new_coll coll2

    where = is_collection
    scope = { homepath + 'testsearch' => :infinity }
    response = @request.search('testsearch', scope, where, :allprop)

    # search should return 3 results including the collection itself
    assert_num_search_results 3, response

    # make sure we got coll1 and coll2
    assert_not_nil response[homepath + coll1]
    assert_not_nil response[homepath + coll2]

    # cleanup
    delete_coll 'testsearch'
  end

  def test_search_lb_is_bit
    new_coll 'bits'
    new_coll 'bits/bit1'
    new_coll 'bits/bit2'
    new_file 'bits/nonbit1'

    where = is_bit
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, :allprop)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got both bits
    assert_not_nil response[homepath + 'bits/bit1']
    assert_not_nil response[homepath + 'bits/bit2']

    response = @request.search('', { homepath + 'bits' => '1' }, where, :allprop)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got both bits
    assert_not_nil response[homepath + 'bits/bit1']
    assert_not_nil response[homepath + 'bits/bit2']

    # cleanup
    ensure
        delete_coll 'bits'
  end

  def test_search_is_defined
    file1 = 'file1'
    file2 = 'file2'
    file3 = 'file3'

    new_file file1, StringIO.new("file1")
    new_file file2, StringIO.new("file2")
    new_file file3, StringIO.new("file3")

    test_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'testprop')
    response = @request.proppatch(file1, { test_pkey => 'a' })
    assert_equal '207', response.status

    response = @request.proppatch(file3, { test_pkey => 'aa' })
    assert_equal '207', response.status

    # search for files for which testprop is defined
    where = is_defined(test_pkey)
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, :displayname)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got file1 and file3
    assert_not_nil response[homepath + 'file1']
    assert_not_nil response[homepath + 'file3']

    # cleanup
    delete_file file1
    delete_file file2
    delete_file file3
  end

  def test_search_multiple_scope
    file1 = 'file1'
    file2 = 'file2'
    testfile1 = testhome + 'file1'
    testfile2 = testhome + 'file2'

    new_file file1, StringIO.new("file1")
    new_file file2, StringIO.new("file2")
    new_file testfile1, StringIO.new("file1"), testcreds
    new_file testfile2, StringIO.new("file2"), testcreds

    tag_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'tag')
    response = @request.proppatch(file1, { tag_pkey => 'interesting' })
    assert_equal '207', response.status

    response = @request.proppatch(file2, { tag_pkey => 'boring' })
    assert_equal '207', response.status

    response = @request.proppatch(testfile1, { tag_pkey => 'boring' }, testcreds)
    assert_equal '207', response.status

    response = @request.proppatch(testfile2, { tag_pkey => 'interesting' }, testcreds)
    assert_equal '207', response.status

    # grant read on home to test user
    grant_read = RubyDav::Ace.new(:grant, test_principal_uri, false, :read)
    add_ace_and_set_acl '', grant_read

    # search for interesting files in home & testhome
    where = eq(tag_pkey, 'interesting')
    scope = { homepath => :infinity, testhomepath => :infinity }
    response = @request.search('', scope, where, tag_pkey, testcreds)

    # search should return 2 results
    assert_num_search_results 2, response

    # make sure we got file1, testfile2
    assert_not_nil response[homepath + 'file1']
    assert_not_nil response[testhomepath + 'file2']

    # cleanup
    delete_file file1
    delete_file file2
    delete_file testfile1, testcreds
    delete_file testfile2, testcreds
  end

  def test_search_orderby_limit
    new_coll 'testsearch'
    file1 = 'testsearch/file1'
    file2 = 'testsearch/file2'
    file3 = 'testsearch/file3'

    put_file_w_size file1, 50
    put_file_w_size file2, 500
    put_file_w_size file3, 5000

    where = gt(:getcontentlength, 0)
    scope = { homepath + 'testsearch' => :infinity }

    response = @request.search('testsearch', scope, where, :allprop, :orderby => [[:getcontentlength, :ascending]], :limit => 1 )

    # search should return 1 result
    assert_num_search_results 1, response

    # the result must contain file1
    assert_not_nil response[homepath + file1]

    response = @request.search('testsearch', scope, where, :allprop, :orderby => [[:getcontentlength, :descending]], :limit => 1 )

    # search should return 1 result
    assert_num_search_results 1, response

    # the result must contain file3
    assert_not_nil response[homepath + file3]

    # cleanup
    delete_coll 'testsearch'
  end

  def test_search_offset
    new_coll 'testsearch'

    for i in (1..10) 
        new_file "testsearch/file#{i}", StringIO.new("file")
    end

    where = gt(:getcontentlength, 0)
    scope = { homepath + 'testsearch' => :infinity }

    response = @request.search('testsearch', scope, where, :allprop, :offset => 5)

    # search should return 5 results
    assert_num_search_results 5, response

    # cleanup
    delete_coll 'testsearch'
  end

  def test_search_depth1_searches_the_collection
    new_coll 'testsearch'
    
    where = is_collection
    scope = { homepath + 'testsearch' => 1 }
    
    response = @request.search('testsearch', scope, where, :allprop)
    assert_num_search_results 1, response

    delete_coll 'testsearch'
  end

  def test_search_depth0_searches_the_collection
    new_coll 'testsearch'
    
    where = is_collection
    scope = { homepath + 'testsearch' => 0 }
    
    response = @request.search('testsearch', scope, where, :allprop)
    assert_num_search_results 1, response

    delete_coll 'testsearch'
  end

  def test_search_typed_literals
    put_file_w_size 'file1', 64
    put_file_w_size 'file2', 1024

    where = <<END_OF_WHERE
<lt xmlns="DAV:"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <prop><getcontentlength/></prop>
  <typed-literal xsi:type="xs:integer">512</typed-literal>
</lt>
END_OF_WHERE

    scope = { homepath => :infinity }

    response = @request.search('', scope , where, :allprop)
    
    # search should return 1 result
    assert_num_search_results 1, response

    # the result must contain file1
    file1response = response[homepath + 'file1']
    assert_not_nil file1response

    # property getcontentlength must've been reported
    assert_equal 64, file1response[:getcontentlength].inner_value.to_i

    # cleanup
    delete_file 'file1'
    delete_file 'file2'
  end

  def test_search_dead_property_with_special_characters
    new_file 'test_search', StringIO.new("test")

    dead_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'special-dead')
    response = @request.proppatch('test_search', { dead_pkey => 'test' })
    assert_equal '207', response.status

    # search for the special-dead property
    where = eq(dead_pkey, 'test')
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, dead_pkey)

    # search should return 1 result
    assert_num_search_results 1, response

    # cleanup
    delete_file 'test_search'
  end

  def test_search_namespaces
    new_file 'test_search', StringIO.new("test")

    # search for DAV:owner
    where = _not(is_collection)
    scope = { homepath => :infinity }
    responses = @request.search('', scope, where, :owner)
    assert_num_search_results 1, responses
    response = responses[homepath + 'test_search']
    assert_not_nil response
    assert_not_nil response[:owner]

    # now search for owner property with incorrect namespace
    bad_ns_owner_pkey = RubyDav::PropKey.get('http://www.example.com/ns', 'owner')
    responses = @request.search('', scope, where, bad_ns_owner_pkey)
    assert_num_search_results 1, responses
    response = responses[homepath + 'test_search']
    assert_not_nil response
    assert_equal '404', response[bad_ns_owner_pkey].status

    # cleanup
    delete_file 'test_search'
  end

  def test_search_lb_bitmarks
    new_coll 'bits'
    new_coll 'bits/bit1'
    new_coll 'bits/bit2'
    new_coll 'bits/bit3'
    new_coll 'bits/bit4'
    new_file 'bits/nonbit1'
    new_file 'nonbit2'

    mark 'bits/bit1', 'name', 'Bit 1'
    mark 'bits/bit2', 'name', 'Bit 2'
    mark 'bits/bit1', 'tag', 'yellow'
    mark 'bits/bit3', 'tag', 'green'
    mark 'bits/bit3', 'tag', 'clean'
    mark 'nonbit2', 'name', 'Non Bit 2'
   
    # depth-0, non-bit 
    response = @request.search('nonbit2', { homepath + 'nonbit2' => 0 }, _not(is_collection), 
                            :getlastmodified, :bitmarks => ["tag", "name"])
    assert_equal '207', response.status
    assert_num_search_results 1, response

    # depth-0, is-bit
    response = @request.search('bits/bit1', { homepath + 'bits/bit1' => 0 }, is_bit, 
                            :getlastmodified, :bitmarks => ["tag", "name"])
    assert_equal '207', response.status
    assert_num_search_results 1, response

    where = is_bit
    scope = { homepath => :infinity }

    # depth-infinity, is-bit
    response = @request.search('', scope, where, 
                            :getlastmodified, :bitmarks => ["tag", "name"])
    assert_equal '207', response.status
    assert_num_search_results 4, response

    # is-bit & tag='green'
    response = @request.search('', scope, _and(is_bit, eq(:tag, 'green', true)), 
                            :getlastmodified, :bitmarks => ["tag", "name"])
    assert_equal '207', response.status
    assert_num_search_results 1, response
    
    response = @request.search('', scope, where, 
                            :getlastmodified, :bitmarks => ["tag"])
    assert_equal '207', response.status
    assert_num_search_results 4, response

   # TODO: test the actual bitmarks returned

  ensure
    delete_coll 'bits'
    delete_file 'nonbit2'
  end

  def test_search_lb_lastmodified
    setup_bits

    sleep 3
    new_file 'bits/bit2/index.html'
    
    response = @request.search('', { homepath => :infinity }, is_bit, :allprop, :orderby => [[:lastmodified, :descending]], :limit => 1)

    assert_num_search_results 1, response
    assert_not_nil response[homepath + 'bits/bit2']

    sleep 3
    put_file_w_size 'bits/bit1/index.html', 50
    response = @request.search('', { homepath => :infinity }, is_bit, :allprop, :orderby => [[:lastmodified, :descending]], :limit => 1)

    assert_num_search_results 1, response
    assert_not_nil response[homepath + 'bits/bit1']

    ensure
    delete_coll 'bits'
  end

  def test_search_popularity
    setup_bits

    # GET bit1, should increate it's popularity
    @request.get('bits/bit1/index.html')

    response = @request.search('', { homepath => :infinity }, is_bit, :allprop, :orderby => [[:popularity, :descending]], :limit => 1)

    assert_num_search_results 1, response
    assert_not_nil response[homepath + 'bits/bit1']

    new_file 'bits/bit2/index.html'

    # GET bit2 twice, making it more popular than bit1
    @request.get('bits/bit2/index.html')
    @request.get('bits/bit2/index.html')

    response = @request.search('', { homepath => :infinity }, is_bit, :allprop, :orderby => [[:popularity, :descending]], :limit => 1)

    assert_num_search_results 1, response
    assert_not_nil response[homepath + 'bits/bit2']

    ensure
    delete_coll 'bits'
  end

  def test_property_stats_report
    setup_bits

    # use current time as a unique value for tags
    tag1 = Time.now.to_f
    tag2 = tag1 + 1

    mark 'bits/bit1', 'tag', tag1
    mark 'bits/bit2', 'tag', tag1
    mark 'bits/bit2', 'tag', tag2

    stream = RubyDav.build_xml_stream do |xml|
      xml.LB(:"property-stats", "xmlns:LB" => "http://limebits.com/ns/1.0/") do
        xml.LB(:prop) do
          xml.LB(:tag)
        end
        xml.LB(:"sample-set") do
          xml.LB(:value, tag1.to_s)
          xml.LB(:value, tag2.to_s)
        end
        xml.LB(:stat) do
          xml.LB(:count)
        end
      end
    end

    response = @request.report('', stream)
    assert_equal '200', response.status
    assert_xml_matches response.body do |xml|
      xml.xmlns! :LB => 'http://limebits.com/ns/1.0/'
      xml.LB(:"property-stats") do
        xml.LB(:prop) do
          xml.LB(:tag)
        end
        xml.LB(:"sample-set") do
          xml.LB(:stat) do
            xml.LB(:value, tag1.to_s)
            xml.LB(:count, "2")
          end
          xml.LB(:stat) do
            xml.LB(:value, tag2.to_s)
            xml.LB(:count, "1")
          end
        end
      end
    end

    ensure
    delete_coll 'bits'
  end

  def setup_bits
    new_coll 'bits'
    new_coll 'bits/bit1'
    new_coll 'bits/bit2'
    new_file 'bits/bit1/index.html'
  end

  def mark bit, name, value
    uuid = get_uuid bit
    tagp_key = bm_key name
    uniq = Time.new.to_f * 1000

    response = @request.mkcol('/bitmarks/' + uuid, :if_none_match => '*')
    new_coll '/bitmarks/' + uuid + '/' + uniq.to_s
    response = @request.proppatch('/bitmarks/' + uuid + '/' + uniq.to_s, { tagp_key => value })
    assert_equal '207', response.status
    assert_equal '200', response[tagp_key].status
  end

  def get_uuid bit
    response = @request.propfind(bit, 0, :"resource-id")
    assert_equal '207', response.status
    value = RubyDav.find_first_text response[:"resource-id"].element, "D:href"
    return value.to_s.gsub(/(.*:)/, '').gsub(/-/,'')
  end

  def assert_num_search_results exp, response
    assert_equal exp, response.resources.length
  end

  def homepath
    URI.parse(@host).path
  end

  def bm_key name
    RubyDav::PropKey.get('http://limebits.com/ns/1.0/', name )
  end
end
