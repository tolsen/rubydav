require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'
require 'test/unit/xml'
require 'time'

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

  def test_propfind_allprop_include
    new_file 'file'
    response = @request.propfind 'file', 0, :allprop, :'resource-id'
    assert_equal '207', response.status
    resource_id_pk = RubyDav::PropKey.get 'DAV:', 'resource-id'
    assert response.resources["#{@uri.path}file"].include?(resource_id_pk)
  ensure
    delete_file 'file'
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

  def glm_pkey
    RubyDav::PropKey.get("DAV:", "getlastmodified")
  end
    
  def test_getlastmodified
    new_file 'testfile', StringIO.new("test")

    response = @request.propfind('testfile', 0, :getlastmodified)
    assert_equal '207', response.status
    getlastmodified1 = Time.httpdate(response[glm_pkey].inner_value)

    sleep 3
    response = @request.put('testfile', @stream)
    assert_equal '204', response.status

    response = @request.propfind('testfile', 0, :getlastmodified)
    assert_equal '207', response.status
    getlastmodified2 = Time.httpdate(response[glm_pkey].inner_value)

    assert getlastmodified1 < getlastmodified2
  ensure
    delete_file 'testfile'
  end

  def test_getlastmodified_depth_infinity
    new_coll 'glm_inf'
    new_file 'glm_inf/testfile', StringIO.new("test")

    response = @request.propfind('glm_inf', RubyDav::INFINITY, :getlastmodified)
    assert_equal '207', response.status
    testfile_response = response[homepath + 'glm_inf/testfile']
    assert_not_nil testfile_response
    getlastmodified1 = Time.httpdate(testfile_response[glm_pkey].inner_value)

    sleep 3
    response = @request.put('glm_inf/testfile', @stream)
    assert_equal '204', response.status

    response = @request.propfind('glm_inf', RubyDav::INFINITY, :getlastmodified)
    assert_equal '207', response.status
    testfile_response = response[homepath + 'glm_inf/testfile']
    assert_not_nil testfile_response
    getlastmodified2 = Time.httpdate(testfile_response[glm_pkey].inner_value)

    assert getlastmodified1 < getlastmodified2
  ensure
    delete_coll 'glm_inf'
  end

  def test_getlastmodified_move
    new_coll 'glm_move_src'
    new_coll 'glm_move_dst'
    new_file 'glm_move_src/testfile', StringIO.new("test src")
    
    sleep 3
    new_file 'glm_move_dst/testfile', StringIO.new("test dst")

    # getlastmodifed for destination
    response = @request.propfind('glm_move_dst', RubyDav::INFINITY, :getlastmodified)
    assert_equal '207', response.status
    testfile_response = response[homepath + 'glm_move_dst/testfile']
    assert_not_nil testfile_response
    testfile_glm1 = Time.httpdate(testfile_response[glm_pkey].inner_value)
    dst_response = response[homepath + 'glm_move_dst']
    assert_not_nil dst_response
    dst_glm1 = Time.httpdate(dst_response[glm_pkey].inner_value)

    # move src to dst
    response = @request.move('glm_move_src', 'glm_move_dst', true)
    assert_equal '204', response.status

    # now request getlastmodified for destination
    response = @request.propfind('glm_move_dst', RubyDav::INFINITY, :getlastmodified)
    assert_equal '207', response.status
    testfile_response = response[homepath + 'glm_move_dst/testfile']
    assert_not_nil testfile_response
    testfile_glm2 = Time.httpdate(testfile_response[glm_pkey].inner_value)
    dst_response = response[homepath + 'glm_move_dst']
    assert_not_nil dst_response
    dst_glm2 = Time.httpdate(dst_response[glm_pkey].inner_value)

    assert dst_glm2 >= dst_glm1
    assert testfile_glm2 >= testfile_glm1

    ensure
    delete_coll 'glm_move_src'
    delete_coll 'glm_move_dst'
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
  ensure
    delete_file 'testfile'
  end

  def test_displayname
    new_file 'testfile', StringIO.new("test")
    
    response = @request.propfind('testfile', 0, :displayname)
    assert_equal '207', response.status
    assert_equal 'testfile', response[:displayname].inner_value
  ensure
    delete_file 'testfile'
  end

  def test_dead_properties_of_child_collections_are_retained_on_move
    new_coll 'a'
    new_coll 'a/b'
    new_coll 'a/b/c'

    author_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')
    publisher_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'publisher')

    # add a property to the source
    response = @request.proppatch('a/b/c', {author_pkey => 'myname'})
    assert response[author_pkey].success?

    # move to destination
    response = @request.move('a', 'd')
    assert_equal '201', response.status

    # check that author is correct on the destination
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[author_pkey].inner_value

    # change the property values on the destination
    response = @request.proppatch('d/b/c', { author_pkey => 'dummyname', publisher_pkey => 'dummy'})
    assert response[author_pkey].success?
    assert response[publisher_pkey].success?

    # let's do it again. this time we'll overwrite
    ['a', 'a/b', 'a/b/c'].each { |url| assert_equal '201', @request.mkcol(url).status }

    # add a property to the source
    response = @request.proppatch('a/b/c', {author_pkey => 'newname'})
    assert response[author_pkey].success?

    # move to destination
    response = @request.move('a', 'd')
    assert_equal '204', response.status

    # make sure the props are right
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'newname',  response[author_pkey].inner_value
    assert_nil response[publisher_pkey]
  ensure
    delete_coll 'd'
  end

  def test_dead_properties_of_child_collections_are_copied_over_correctly_on_copy
    new_coll 'a'
    new_coll 'a/b'
    new_coll 'a/b/c'

    author_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')
    publisher_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'publisher')

    response = @request.proppatch('a/b/c', { author_pkey => 'myname'})
    assert_equal '207',response.status
    assert response[author_pkey].success?
    
    response = @request.copy('a', 'd')
    assert_equal '201', response.status

    # check that the property was copied over correctly
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[author_pkey].inner_value

    # change the property value on the destination
    response = @request.proppatch('d/b/c', { author_pkey => 'dummyname', publisher_pkey => 'dummy'})
    assert_equal '207', response.status
    assert response[author_pkey].success?
    assert response[publisher_pkey].success?

    # copy over again, this time it'll overwrite
    response = @request.copy('a', 'd')
    assert_equal '204', response.status

    # test that the destination has the new property values
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[author_pkey].inner_value
    assert_nil response[publisher_pkey]
  ensure
    delete_coll 'a'
    delete_coll 'd'
  end

  def test_dead_properties_of_child_resources_are_copied_over_correctly_on_copy
    new_coll 'a'
    new_coll 'a/b'
    new_file 'a/b/c'
    delete_coll 'd'

    author_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'author')
    publisher_pkey = RubyDav::PropKey.get('http://example.org/mynamespace', 'publisher')

    response = @request.proppatch('a/b/c', { author_pkey => 'myname'})
    assert_equal '207',response.status
    assert response[author_pkey].success?
    
    response = @request.copy('a', 'd')
    assert_equal '201', response.status

    # check that the property was copied over correctly
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[author_pkey].inner_value

    # change the property value on the destination
    response = @request.proppatch('d/b/c', { author_pkey => 'dummyname', publisher_pkey => 'dummy'})
    assert response[author_pkey].success?
    assert response[publisher_pkey].success?

    # copy over again, this time it'll overwrite
    response = @request.copy('a', 'd')
    assert_equal '204', response.status

    # test that the destination has the new property values
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[author_pkey].inner_value
    assert_nil response[publisher_pkey]
  ensure
    delete_coll 'a'
    delete_coll 'd'
  end

  def test_displayname_retained_on_copy
    new_coll 'a'
    new_coll 'a/b'
    new_coll 'a/b/c'
    delete_coll 'd'

    # add a property to the source
    response = @request.proppatch('a', {:displayname => 'My name'})
    assert response[:displayname]
    
    response = @request.proppatch('a/b/c', {:displayname => 'myname'})
    assert response[:displayname]

    # copy to destination
    response = @request.copy('a', 'd')
    assert_equal '201', response.status

    # check that displayname is correct on the destination
    response = @request.propfind('d', 0, :allprop)
    assert_equal 'My name', response[:displayname].inner_value

    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'myname', response[:displayname].inner_value

    # change the property values on the destination
    response = @request.proppatch('d/b/c', { :displayname => 'dummyname' })
    assert response[:displayname].success?

    # add a property to the source
    response = @request.proppatch('a/b/c', {:displayname => 'newname'})
    assert response[:displayname].success?

    # move to destination
    response = @request.copy('a', 'd')
    assert_equal '204', response.status

    # make sure the props are right
    response = @request.propfind('d/b/c', 0, :allprop)
    assert_equal 'newname',  response[:displayname].inner_value
  ensure
    delete_coll 'a'
    delete_coll 'd'
  end

end
