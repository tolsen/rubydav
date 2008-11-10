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
    fileresponse = response.responsehash[homepath + 'file']
    assert_not_nil fileresponse

    # property getcontentlength must've been reported
    assert_equal 64, fileresponse.propertyhash[RubyDav::PropKey.strictly_prop_key(:getcontentlength)].to_i

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
    fileresponse = response.responsehash[homepath + 'test-search-resource-id/file']
    assert_not_nil fileresponse

    # property resource-id must've been reported
    assert_not_nil fileresponse.propertyhash[RubyDav::PropKey.strictly_prop_key(:'resource-id')]

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
    file1response = response.responsehash[homepath + 'file1']
    file3response = response.responsehash[homepath + 'file3']
    assert_not_nil file1response
    assert_not_nil file3response

    # dead property tag must've been reported as 'interesting'
    assert_equal 'interesting', file1response.propertyhash[tag_pkey]
    assert_equal 'interesting', file3response.propertyhash[tag_pkey]

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
    assert_not_nil response.responsehash[homepath + 'file2']
    assert_not_nil response.responsehash[homepath + 'file3']

    # search for files with more than aa rating
    where = like(rating_pkey, 'aa_')
    scope = { homepath => :infinity }
    response = @request.search('', scope, where, rating_pkey)

    # search should return 1 result
    assert_num_search_results 1, response

    # make sure we got file3
    assert_not_nil response.responsehash[homepath + 'file3']

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
    assert_not_nil response.responsehash[homepath + coll1]
    assert_not_nil response.responsehash[homepath + coll2]

    # cleanup
    delete_coll 'testsearch'
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
    assert_not_nil response.responsehash[homepath + 'file1']
    assert_not_nil response.responsehash[homepath + 'file3']

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
    assert_not_nil response.responsehash[homepath + 'file1']
    assert_not_nil response.responsehash[testhomepath + 'file2']

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
    assert_not_nil response.responsehash[homepath + file1]

    response = @request.search('testsearch', scope, where, :allprop, :orderby => [[:getcontentlength, :descending]], :limit => 1 )

    # search should return 1 result
    assert_num_search_results 1, response

    # the result must contain file3
    assert_not_nil response.responsehash[homepath + file3]

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
    file1response = response.responsehash[homepath + 'file1']
    assert_not_nil file1response

    # property getcontentlength must've been reported
    assert_equal 64, file1response.propertyhash[RubyDav::PropKey.strictly_prop_key(:getcontentlength)].to_i

    # cleanup
    delete_file 'file1'
    delete_file 'file2'
  end


  def assert_num_search_results exp, response
    assert_equal exp+1, response.responses.length
  end

  def homepath
    URI.parse(@host).path
  end
end
