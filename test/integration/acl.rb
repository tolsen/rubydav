require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'
require 'rubygems'
require 'builder'

class WebDavAclTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_anon_file_access
    # delete and put new file
    new_file 'file'
    
    # try to get it anonymously and assert failure
    response = @request.get('file', :username => nil)
    assert_equal '401', response.status

    # grant read permission for anonymous users on this file
    ace = RubyDav::Ace.new(:grant, :unauthenticated, false, :read);
    acl = add_ace_and_set_acl 'file', ace

    # get the file anonymously now
    response = @request.get('file')
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    # restore acl of file
    if acl
      acl.shift
      # set the access control properties of the resource
      response = @request.acl('file', acl)
      assert_equal '200', response.status
    end

    # get the file anonymously now
    response = @request.get('file', :username => nil)
    assert_equal '401', response.status

    # authenticate and fetch one last time
    response = @request.get('file')
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    # cleanup
    delete_file 'file'

    # should we put file of same name and check that it's secure by default?
  end

  # grant test user all privileges and verify he can perform operations that need them
  def test_grant_other_user_privileges
    new_coll 'coll'
    new_coll 'coll/subcoll'
    new_file 'coll/subcoll/file'

    # grant test user all privileges on coll
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    acl = add_ace_and_set_acl 'coll', ace

    # try deleting file in subcollection of coll using test user
    delete_file('coll/subcoll/file', testcreds)

    # cleanup
    delete_coll 'coll'
  end

  def setup_acl
    # create new file
    @testfile = 'file'
    new_file @testfile

    # get the acl 
    @response = @request.propfind_acl('file', 0)
    assert !@response.error?
    @acl = @response.acl
  end

  def teardown_acl
    delete_file 'file'
  end

  def test_acl_evaluation_order
    setup_acl
    
    # Note: Specific to limestone
    # Assuming a newly created resource has only protected/inherited aces.
    assert @acl.empty?

    @acl << RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    @acl << RubyDav::Ace.new(:deny, test_principal_uri, false, :read)

    response = @request.acl('file', @acl)
    assert_equal '200', response.status

    response = @request.get('file', testcreds)
    assert_equal '200', response.status

    @acl.reverse!
    response = @request.acl('file', @acl)
    assert_equal '200', response.status

    response = @request.get('file', testcreds)
    assert_equal '403', response.status

    @acl.reverse!
    response = @request.acl('file', @acl)
    assert_equal '200', response.status

    response = @request.get('file', testcreds)
    assert_equal '200', response.status
  end
  
  # Note: specific to limestone
  # protected > self unprotected > inherited
  # each set being ordered in itself
  # @see also test_acl_evaluation_order, test_current_user_privilege_set
  def test_ace_priority
    publiccol = 'public'
    privatecol = 'public/private'
    publicfile = 'public/file'
    privatefile = 'public/private/file'
    testfile = 'public/private/allowtest'

    new_coll publiccol
    new_coll privatecol
    new_file publicfile, StringIO.new("public")
    new_file privatefile, StringIO.new("private")
    new_file testfile, StringIO.new("test")

    # grant read to all on publiccol
    public_ace = RubyDav::Ace.new(:grant, :all, false, :read)
    add_ace_and_set_acl publiccol, public_ace

    # deny read to all on privatecol
    private_ace = RubyDav::Ace.new(:deny, :all, false, :read)
    add_ace_and_set_acl privatecol, private_ace

    # share testfile with 'test' user
    test_ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :read)
    add_ace_and_set_acl testfile, test_ace
    
    # 'test' user should be able to get publicfile,
    # because of the inherited public_ace
    response = @request.get(publicfile, testcreds)
    assert_equal '200', response.status
    assert_equal "public", response.body

    # 'test' user should not be able to get privatefile,
    # because of ordering within inherited aces,
    # inherited private_ace > inherited public_ace
    response = @request.get(privatefile, testcreds)
    assert_equal '403', response.status

    # 'test' user should be able to read testfile,
    # because self test_ace > inherited private_ace > inherited public_ace
    response = @request.get(testfile, testcreds)
    assert_equal '200', response.status
    assert_equal "test", response.body

    # cleanup
    delete_coll publiccol
  end

  def test_unlock_privilege_and_ace_order
    # create the file
    new_file 'file'

    # get a lock on the file
    response = @request.lock('file', RubyDav::LockInfo.new)
    assert_equal '200', response.status
    lockinfo = response.lockinfo

    # try unlocking
    response = @request.unlock('file', lockinfo.token, testcreds)
    # Must have failed with 403
    assert_equal '403', response.status

    # test user doesn't have any permissions. grant him a reversed acl and retry
    modify_acl 'file' do |acl|
      # Note: Specific to limestone
      # Assuming a newly created resource has only protected/inherited aces.
      assert acl.empty?

      acl << RubyDav::Ace.new(:deny, test_principal_uri, false, :all)
      acl << RubyDav::Ace.new(:grant, test_principal_uri, false, :unlock)
    end
    response = @request.unlock('file', lockinfo.token, testcreds)
    assert_equal '403', response.status
    
    # correct the acl order and retry
    modify_acl 'file' do |acl|
      acl.reverse!
    end

    response = @request.unlock('file', lockinfo.token, testcreds)
    assert_equal '204', response.status

    # cleanup
    delete_file 'file'
  end

  def test_privilege_read_acl
    expected_acl = RubyDav::Acl.new
    expected_acl << RubyDav::Ace.new(:grant, test_principal_uri, false, 'read-acl')
    expected_acl << RubyDav::Ace.new(:grant, test_principal_uri, false, 'read')

    assert_read_acl_related_privilege "read-acl" do |response|
      assert_equal expected_acl, response.acl
    end
  end

  def test_privilege_read_current_user_privilege_set
    assert_read_acl_related_privilege "read-current-user-privilege-set"
  end
  
  def test_supported_privilege_set
    new_file 'file'
    sps_key = RubyDav::PropKey.get('DAV:', 'supported-privilege-set')

    response = @request.propfind('file', 0, sps_key)
    assert_equal '207', response.status
    assert_equal '200', response.statuses(sps_key)

    doc = REXML::Document.new(response.propertyhash[sps_key])

    # More specific xpath expresssions are not working!!
    REXML::XPath.each(doc.root, "//*") do |element|
      if element.name == "supported-privilege"
        has_description = false
        REXML::XPath.each(element) do |child|
          has_description = true if child.name == "description"
        end
        assert has_description
      end
    end
    
    delete_file 'file'
  end

  def test_dav_property_aces
    tdp_key = RubyDav::PropKey.get('testns:', 'test-dav-prop')
    help_test_dav_property_aces(tdp_key)
  end

  def help_test_dav_property_aces(tdp_key)
    testfile = 'file'
    new_file testfile

    # create a new dead property, suitable to be a DAV:property
    hrefxml = ::Builder::XmlMarkup.new()
    hrefxml.D(:href, test_principal_uri)

    response = @request.proppatch(testfile, { tdp_key => hrefxml })
    assert_equal '207', response.status
    assert_equal '200', response.statuses(tdp_key)

    dav_property_ace = RubyDav::Ace.new(:grant, tdp_key, false, :read)
    acl = add_ace_and_set_acl testfile, dav_property_ace
    
    # verify that the ACL now contains the newly added DAV:property ACE
    response = @request.propfind_acl(testfile, 0)
    assert_equal '207', response.status
    acl = response.acl
    found_prop_ace = false
    acl.each { |ace| if ace.principal == tdp_key 
                       found_prop_ace = true 
                     end }
    assert found_prop_ace

    # check if test user can get the file now
    response = @request.get(testfile, testcreds)
    assert_equal '200', response.status

    # change the value of test-dav-prop
    user = @creds[:username]
    userhrefxml = ::Builder::XmlMarkup.new()
    userhrefxml.D(:href, get_principal_uri(user))
    response = @request.proppatch(testfile, { tdp_key => userhrefxml })
    assert_equal '207', response.status
    assert_equal '200', response.statuses(tdp_key)

    # now test user should not be able to read the file
    response = @request.get(testfile, testcreds)
    assert_equal '403', response.status

    # cleanup
    delete_file testfile
  end

  def test_self_aces
    user = @creds[:username]
    principal_uri = get_principal_uri(user)

    dav_self_ace = RubyDav::Ace.new(:deny, :self, false, :write)
    acl = add_ace_and_set_acl principal_uri,  dav_self_ace
    
    # verify that the ACL now contains the newly added DAV:property ACE
    response = @request.propfind_acl(principal_uri, 0)
    assert_equal '207', response.status
    acl = response.acl
    found_self_ace = false
    acl.each { |ace| if ace.principal == :self 
                       found_self_ace = true 
                     end }
    assert found_self_ace

    # restore the acl
    acl.shift
    response = @request.acl(principal_uri, acl)
    assert_equal '200', response.status
  end

  # Make sure <DAV:self/> and <DAV:property><DAV:self/></DAV:property>
  # are handled correctly.
  def test_dav_self_property_ace
    # the DAV:self *dead* property
    self_key = RubyDav::PropKey.get('DAV:', 'self')

    # test property aces using DAV:self dead property
    help_test_dav_property_aces(self_key)
  end

  def test_ace_conflict
    setup_acl

    # add an ACE, so that we have something to test for
    @acl << RubyDav::Ace.new(:grant, test_principal_uri, false, :write)
    response = @request.acl(@testfile, @acl)
    assert_equal '200', response.status

    new_acl = RubyDav::Acl.new
    new_acl << RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    new_acl << RubyDav::Ace.new(:deny, test_principal_uri, false, :all)

    # setting conflicting ACEs should result in 409
    response = @request.acl(@testfile, new_acl)
    assert_equal '409', response.status
    
    # test that the ACL did not change
    response = @request.propfind_acl(@testfile, 0)
    assert_equal '207', response.status
    assert @acl.eq? response.acl

    ensure
    teardown_acl
  end

  def test_acl_preconditions
    setup_acl
    
    # test for no-protected-ace-conflict precondition
    # assuming server sets atleast one protected ace per resource
    assert (!@response.protected_acl.nil?)
    protected_acl = @response.protected_acl
    protected_ace = protected_acl.first

    # try to set an ace, conflicting with the proctected ace
    # invert 'action', guaranteed to conflict with original ace
    if protected_ace.action == :grant
      action = :deny
    else
      action = :grant
    end
    ace = RubyDav::Ace.new(action, protected_ace.principal, false, protected_ace.privileges[0])
    @acl.unshift ace
    response = @request.acl(@testfile, @acl)
    assert_equal '403', response.status

    # expect 'no-protected-ace-conflict' error
    assert_dav_error response, "no-protected-ace-conflict"

    # revert acl back to its original state
    @acl.shift
    
    # test for no-ace-conflict precondition
    # add two conflicting aces to acl
    ace1 = RubyDav::Ace.new(:grant, test_principal_uri, false, :all)
    ace2 = RubyDav::Ace.new(:deny, test_principal_uri, false, :all)
    @acl.unshift(ace1).unshift(ace2)

    response = @request.acl(@testfile, @acl)
    assert_equal '409', response.status

    # expect 'no-ace-conflict' error
    assert_dav_error response, "no-ace-conflict"

    # revert acl back to its original state
    @acl.shift
    @acl.shift

    # test for not-supported-privilege precondition
    # try to grant a fake privilege
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, 'fakepriv')
    @acl.unshift ace

    response = @request.acl(@testfile, @acl)
    assert_equal '403', response.status

    # expect 'not-supported-privilege' error
    assert_dav_error response, "not-supported-privilege"

    # revert acl back to its original state
    @acl.shift

    # test for recognized-principal precondition
    # try to set an ace with a fake principal
    # NOTE: specific to limestone
    ace = RubyDav::Ace.new(:grant, get_principal_uri('fakeprin'), false, :all)
    @acl.unshift ace

    response = @request.acl(@testfile, @acl)
    assert_equal '403', response.status

    # expect 'recognized-principal' error
    assert !response.dav_error.nil?
    assert_dav_error response, "recognized-principal"

    # revert acl back to its original state
    @acl.shift
    
  ensure
    teardown_acl
  end

  def test_acl_when_principal_is_not_a_principal
    setup_acl

    @acl << RubyDav::Ace.new(:grant, @host, false, :read)

    response = @request.acl(@testfile, @acl)
    assert_equal '403', response.status

    # expect 'recognized-principal' error
    assert_dav_error response, "recognized-principal"
  ensure
    teardown_acl
  end
    
  # this should probably be moved to acl_props.rb
  def test_child_read_for_propfind_depth_one
    
    # create a new collection 'coll'
    testcol = 'coll'
    testfile1 = 'coll/file1'
    testfile2 = 'coll/file2'

    new_coll testcol
    new_file testfile1, StringIO.new("test1")
    new_file testfile2, StringIO.new("test2")

    grantread = RubyDav::Ace.new(:grant, test_principal_uri, false, :read)
    denyread = RubyDav::Ace.new(:deny, test_principal_uri, false, :read)

    # grant :read on coll
    acl = add_ace_and_set_acl testcol, grantread

    # grant :read on file1
    acl = add_ace_and_set_acl testfile1, grantread

    # deny :read on file2
    acl = add_ace_and_set_acl testfile2, denyread

    # now, propfind depth 1 on coll
    response = @request.propfind(testcol, 1, :allprop, testcreds)
    assert_equal '207', response.status

    # ensure that we got 'file2' in the listing
    assert response.children.include?('file2')

    # the status associated with file2 must be 403
    assert '403', response.children['file2'].status

    # cleanup
    delete_coll testcol
  end

  def test_current_user_privilege_set
    testcol = 'testcol'
    new_coll testcol

    rcups = :"read-current-user-privilege-set"
    
    # grant read, rcups & write
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :read, rcups, :write)
    acl = add_ace_and_set_acl testcol, ace

    # get cups for 'test'
    response = @request.propfind_cups(testcol, 0, testcreds)
    assert_equal '207', response.status
    assert_equal '200', response.cups_status
    privileges = response.privileges

    # ensure we got back read, rcups & write
    assert privileges.include?('read')
    assert privileges.include?('read-current-user-privilege-set')
    assert privileges.include?('write')

    # both aggregate privileges and their contained privileges must be listed
    # Also, from sec 3.12 RFC2518bis, write MUST contain bind, unbind, 
    # write-properties and write-content.
    write_privs = [ 'bind', 'unbind', 'write-properties', 'write-content']
    write_privs.each { |priv| assert privileges.include?(priv) }

    # now remove write privilege
    acl.shift
    acl.unshift RubyDav::Ace.new(:grant, test_principal_uri, false, :read, rcups)
    response = @request.acl(testcol, acl)
    assert_equal '200', response.status

    # now, get cups for 'test'
    response = @request.propfind_cups(testcol, 0, testcreds)
    assert_equal '207', response.status
    assert_equal '200', response.cups_status
    privileges = response.privileges

    # ensure we got back read, rcups but not write
    assert privileges.include?('read')
    assert privileges.include?('read-current-user-privilege-set')
    assert !privileges.include?('write')

    # also, ensure we did not get back any of the privileges contained in write
    write_privs.each { |priv| assert !privileges.include?(priv) }

    # cleanup
    delete_coll testcol
  end

  def test_acl_principal_all
    testfile = 'testfile'
    new_file testfile
    
    # try to get file anonymously
    response = @request.get(testfile, :username => nil)
    assert_equal '401', response.status

    # try get with 'test' user
    response = @request.get(testfile, testcreds)
    assert_equal '403', response.status

    # grant read to all
    ace = RubyDav::Ace.new(:grant, :all, false, :read)
    acl = add_ace_and_set_acl testfile, ace

    # now, try to get file anonymously
    response = @request.get(testfile)
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    # and, try get with 'test' user
    response = @request.get(testfile, testcreds)
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    #cleanup
    delete_file testfile
  end

  def test_acl_principal_authenticated
    testfile = 'testfile'
    new_file testfile
    
    # try to get file anonymously
    response = @request.get(testfile, :username => nil)
    assert_equal '401', response.status

    # try get with 'test' user
    response = @request.get(testfile, testcreds)
    assert_equal '403', response.status

    # grant read to authenticated
    ace = RubyDav::Ace.new(:grant, :authenticated, false, :read)
    acl = add_ace_and_set_acl testfile, ace

    # now, try to get file anonymously
    response = @request.get(testfile, :username => nil)
    assert_equal '401', response.status

    # and, try get with 'test' user
    response = @request.get(testfile, testcreds)
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    #cleanup
    delete_file testfile
  end

  def test_acl_inheritance
    testcol = 'coll'
    testfile = 'coll/file'

    new_coll testcol
    new_file testfile

    response = @request.propfind_acl(testfile, 0)
    assert_equal '207', response.status
    inherited_acl = response.inherited_acl
    
    # nothing to do if the resource has no inherited ace
    if inherited_acl.nil? 
      return
    end

    # try get with 'test' user
    response = @request.get(testfile, testcreds)
    assert_equal '403', response.status

    inherited_ace = inherited_acl.first
    parent_uri = inherited_ace.url

    # grant read to 'test' on parent
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :read)
    acl = add_ace_and_set_acl parent_uri, ace

    # now, 'test' should be able to get testfile
    response = @request.get(testfile, testcreds)
    assert_equal '200', response.status
    assert_equal @filebody, response.body

    # cleanup
    delete_coll testcol
  end

  def test_put_write_content_permission_denied
    new_file 'foo', StringIO.new('test1')
    response = @request.put('foo', StringIO.new('test2'), testcreds)
    assert_equal '403', response.status
    assert_content_equals 'test1', 'foo'

    # cleanup
    delete_file 'foo'
  end

  def test_put_write_content_permission_granted
    new_file 'foo', StringIO.new('test1')
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, 'write-content')
    acl = add_ace_and_set_acl('foo', ace)
    response = @request.put('foo', StringIO.new('test2'), testcreds)
    assert_equal '204', response.status
    assert_content_equals 'test2', 'foo'

    # cleanup
    delete_file 'foo'
  end

  # helpers

  def modify_acl resource, &block
    response = @request.propfind_acl(resource, 0)
    assert !response.error?
    acl = response.acl
    yield acl
    response = @request.acl(resource, acl)
    assert_equal '200', response.status
  end

  def assert_read_acl_related_privilege privilege
    new_file 'file'

    # try with no permissions
    response = @request.propfind_acl('file', 0, testcreds)

    # test user didn't have :read privilege for propfind
    assert_equal '403', response.status

    modify_acl 'file' do |acl|
      # Note: Specific to limestone
      # Assuming a newly created resource has only protected/inherited aces.
      assert acl.empty?

      # grant :read for propfind but deny read-acl privilege
      acl << RubyDav::Ace.new(:deny, test_principal_uri, false, 'read-acl')
      acl << RubyDav::Ace.new(:grant, test_principal_uri, false, 'read')
    end
    
    # retry with bad permissions
    response = @request.propfind_acl('file', 0, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response.statuses(:acl)

    # change read-acl privilege from deny to grant
    modify_acl 'file' do |acl|
      acl[0] = RubyDav::Ace.new(:grant, test_principal_uri, false, 'read-acl')
    end
    
    # retry with good permissions
    response = @request.propfind_acl('file', 0, testcreds)
    assert_equal '207', response.status
    assert_equal '200', response.statuses(:acl)

    yield response if block_given?
    
    # cleanup
    delete_file 'file'
  end

  def _test_aces_inherited_from_root_are_marked_as_inherited
    new_file 'file'

    response = @request.acl('/', RubyDav::Acl.new, admincreds)
    assert_equal '200', response.status

    response1 = @request.propfind_acl('file', 0)
    assert_equal '200', response1.statuses(:acl)
    assert_equal 0, response1.acl.length

    acl = RubyDav::Acl.new
    ace = RubyDav::Ace.new(:grant, :authenticated, false, 'read', 'read-current-user-privilege-set')
    acl << ace
    
    response = @request.acl('/', acl, admincreds)
    assert_equal '200', response.status
    
    response2 = @request.propfind_acl('file', 0)
    assert_equal '200', response2.statuses(:acl)

    response = @request.acl('/', RubyDav::Acl.new, admincreds)
    assert_equal '200', response.status

    assert_equal response1.protected_acl.length, response2.protected_acl.length

    assert_equal 0, response2.acl.length
    assert_equal((response1.inherited_acl.length + 1), response2.inherited_acl.length)

    delete_file 'file'
  end
end
