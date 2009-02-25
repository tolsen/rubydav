require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'
require 'test/unit/xml'

class WebDavPropsTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_propfind
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201',response.status
    
    #ALLPROP
    response = @request.propfind('file',0, :allprop)
    assert_equal '207',response.status
    
    #PROPNAME
    response = @request.propfind('file',0, :propname)
    assert_equal '207',response.status
    
    response = @request.delete('file')
    response = @request.get('file')
    assert_equal '404', response.status
  end

  def test_propfind_depth_infinity
    # create a resource tree to test depth infinity PROPFINDs
    #                        A
    #                 _______|_______                 
    #                /       |       \
    #                B       C       a
    #         _______|       |       
    #        /       |       |
    #        A       D       E
    #     ___|       |
    #    /   |       |
    #    b   c       d
    #    
    #    Note: Resources with names in CAPS are COLLECTIONS and others are files
    
    new_coll 'a'
    new_coll 'a/b'
    new_coll 'a/c'
    new_file 'a/a', StringIO.new("test")
    new_coll 'a/b/a'
    new_coll 'a/b/d'
    new_coll 'a/c/e'
    new_file 'a/b/a/b', StringIO.new("test")
    new_file 'a/b/a/c', StringIO.new("test")
    new_file 'a/b/d/d', StringIO.new("test")

    response = @request.propfind('', RubyDav::INFINITY, :getetag)
    assert_equal '207', response.status
    # Make sure we got all properties for all resources
    assert_equal 11, response.resources.length

    # cleanup
    delete_coll 'a'
  end

  def test_proppatch
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201',response.status
    ns = 'http://example.org/mynamespace'
    
    #PROPPATCH
    response = @request.proppatch('file', { RubyDav::PropKey.get(ns, 'author') => 'myname'})
    assert_equal '207',response.status
    assert !response.error?
    assert_equal '200', response[RubyDav::PropKey.get(ns, 'author')].status
    
    response = @request.propfind('file', 0, :allprop)
    assert_equal '207',response.status
    
    assert_equal('myname',
                 response[RubyDav::PropKey.get(ns, 'author')].inner_value.strip)
    
    response = @request.delete('file')
    response = @request.get('file')
    assert_equal '404', response.status
  end

  # check that server retains XML Information Items in property values
  def test_mixed_content
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201',response.status

    doc = REXML::Document.new "<x:author xmlns:x='http://example.com/ns'>
      <x:name>Jane Doe</x:name>
      <!-- Jane's contact info -->
      <x:uri type='email' 
             added='2005-11-26'>mailto:jane.doe@example.com</x:uri>
      <x:uri type='web' 
             added='2005-11-27'>http://www.example.com</x:uri>
      <x:notes xmlns:h='http://www.w3.org/1999/xhtml'>
        Jane has been working way <h:em>too</h:em> long on the  
        long-awaited revision of <![CDATA[<RFC2518>]]>.
      </x:notes>
    </x:author>"

    author_prop_key = RubyDav::PropKey.get('http://example.org/ns', 'author')

    # store the xml document as value of a property
    response = @request.proppatch('file', {author_prop_key => doc})
    assert_equal '207',response.status
    assert !response.error?
    assert_equal '200', response[author_prop_key].status

    # retrieve the value of the property from the server
    response = @request.propfind('file', 0, author_prop_key)
    assert_equal '207',response.status
    server_val = response[author_prop_key].inner_value

    # assert that the returned value is xml equivalent to the value we sent
    assert_xml_equal doc, '<?xml version="1.0" encoding="UTF-8"?>' + server_val

    # cleanup
    response = @request.delete('file')
    response = @request.get('file')
    assert_equal '404', response.status
  end

  def test_proppatch_failure_xactional
    response = @request.delete('file')
    response = @request.put('file', @stream)
    assert_equal '201',response.status
    
    # have one legitimate and one illegitimate operation each
    author_prop_key = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')
    update_props = { :resourcetype => 'illegitimate', author_prop_key => 'chetan' }

    state = :illegal_props_list
    begin
      response = @request.proppatch('file', update_props)
      assert !response.error?

      assert_equal '207', response.status
      assert_equal '200', response[author_prop_key].status

      response = @request.propfind('file', 0, author_prop_key)
      assert_equal '207', response.status
      assert_equal 'chetan', response[author_prop_key].inner_value.strip
    rescue Test::Unit::AssertionFailedError
      case state
      when :illegal_props_list
        assert_equal '207',response.status
        assert_equal '424', response[author_prop_key].status
        assert_match /40[3|9]/, response[:resourcetype].status

        response = @request.propfind('file', 0, author_prop_key)
        assert_equal '207', response.status
        assert_equal '404', response[author_prop_key].status

        update_props = { author_prop_key => 'chetan', :resourcetype => 'illegitimate' }
        state = :illegal_reverse
        retry
      when :illegal_reverse
        assert_equal '207',response.status
        assert_equal '424', response[author_prop_key].status
        assert_match /40[3|9]/, response[:resourcetype].status

        response = @request.propfind('file', 0, author_prop_key)
        assert_equal '207', response.status
        assert_equal '404', response[author_prop_key].status

        update_props = { author_prop_key => 'chetan' }
        state = :legal_props
        retry
      when :legal_props
        raise
      end
    ensure
      # cleanup
      response = @request.delete('file')
      assert_equal '204', response.status
    end
  end

  def test_getlastmodified
    new_file 'testfile', StringIO.new("test")
    glm_pkey = RubyDav::PropKey.get("DAV:", "getlastmodified")

    response = @request.propfind('testfile', 0, :getlastmodified)
    assert_equal '207', response.status
    getlastmodified1 = response[glm_pkey].inner_value

    sleep 3
    response = @request.put('testfile', @stream)
    assert_equal '204', response.status

    response = @request.propfind('testfile', 0, :getlastmodified)
    assert_equal '207', response.status
    getlastmodified2 = response[glm_pkey].inner_value

    assert_not_equal getlastmodified1, getlastmodified2

    # cleanup
    delete_file 'testfile'
  end

  def test_creationdate
    new_file 'testfile', StringIO.new("test")
    cdate_pkey = RubyDav::PropKey.get("DAV:", "creationdate")
    
    response = @request.propfind('testfile', 0, :creationdate)
    assert_equal '207', response.status
    creationdate1 = response[cdate_pkey].inner_value

    sleep 3
    response = @request.put('testfile', @stream)
    assert_equal '204', response.status

    response = @request.propfind('testfile', 0, :creationdate)
    assert_equal '207', response.status
    creationdate2 = response[cdate_pkey].inner_value

    assert_equal creationdate1, creationdate2

    # cleanup
    delete_file 'testfile'
  end
end
