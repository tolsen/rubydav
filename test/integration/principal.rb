require 'test/unit'
require 'lib/rubydav'
require 'lib/limestone'
require 'test/integration/webdavtestsetup'

class LimestonePrincipalTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def delete_user user
    response = @request.delete(get_home_path(user), admincreds)
    assert_equal '204', response.status

    response = @request.delete(get_principal_uri(user), admincreds)
    assert_equal '204', response.status
  end

  def test_put_for_creating_user
    response = @request.put_user(get_principal_uri('cartman'), {:new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    delete_user 'cartman'
  end

  def _test_create_user_requires_displayname
    response = @request.put_user(get_principal_uri('cartman'), {:new_password => 'cartman', :email => 'cartman@example.com'})
    assert response.error?

    # sanity check, try to propfind the principal url, should get 404
    response = @request.propfind(get_principal_uri('cartman2'), 0, :displayname )
    assert_equal '404', response.status
  end

  def test_put_for_updating_displayname
    response = @request.put_user(get_principal_uri('cartman'), {:new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status
    
    response = @request.put_user(get_principal_uri('cartman'), {:new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '403', response.status

    # update displayname
    response = @request.put_user(get_principal_uri('cartman'), {:displayname => 'Eric Cartman',  :username => 'cartman', :password => 'cartman'})
    assert_equal '204', response.status

    response = @request.propfind(get_principal_uri('cartman'), 0, :displayname )
    assert_equal '207', response.status
    assert_equal 'Eric Cartman', response[:displayname].strip

    delete_user 'cartman'
  end

  def test_put_for_updating_password_requires_current_password
    response = @request.put_user(get_principal_uri('cartman'), { :new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # try changing password without old password
    response = @request.put_user(get_principal_uri('cartman'), { :new_password => 'manbearpig', :username => 'cartman', :password => 'cartman'})
    assert_equal '400', response.status

    response = @request.put_user(get_principal_uri('cartman'), { :new_password => 'manbearpig', :cur_password => 'cartman', :username => 'cartman', :password => 'cartman'})
    assert_equal '204', response.status

    delete_user 'cartman'
  end

  def test_put_for_updating_email_requires_current_password
    response = @request.put_user(get_principal_uri('cartman'), { :new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # try changing email without password
    response = @request.put_user(get_principal_uri('cartman'), { :email => 'manbearpig@southpark.com', :username => 'cartman', :password => 'cartman'})
    assert_equal '400', response.status

    response = @request.put_user(get_principal_uri('cartman'), { :email => 'manbearpig@southpark.com', :cur_password => 'cartman', :username => 'cartman', :password => 'cartman'})
    assert_equal '204', response.status

    delete_user 'cartman'
  end

  def create_group group_name
    group_url = "/groups/#{group_name}"

    @request.delete group_url, admincreds
    ace = RubyDav::Ace.new(:grant, :authenticated, false, :bind)
    acl = add_ace_and_set_acl '/groups', ace, admincreds

    response = @request.put group_url, StringIO.new("")
    assert_equal '201', response.status
    group_url
  end

  def assert_group_members group_url, *members
    response = @request.propfind(group_url, 0, :"group-member-set")
    assert_equal '207', response.status
    assert_xml_matches "<wrap>" + response[:"group-member-set"] + "</wrap>" do |xml|
      xml.wrap {
        xml.xmlns!({:D => "DAV:" })
        members.each do |prin_url|
          xml.D :href, baseuri + prin_url
        end
      }
    end
  end

  def set_group_members group_url, *members
    hrefxml = ::Builder::XmlMarkup.new()
    members.each do |prin_url|
      hrefxml.D(:href, baseuri + prin_url)
    end
    response = @request.proppatch(group_url, {:"group-member-set" => hrefxml })
    assert_equal '207',response.status
    assert_equal '200', response.statuses(:"group-member-set")
  end

  def test_put_for_creating_group
    group_url = create_group 'testgroup'

    response = @request.propfind(group_url, 0, :resourcetype)
    assert_equal '207', response.status
    assert_match 'D:principal', response[:resourcetype]

    @request.delete group_url, admincreds
  end

  def test_adding_user_to_group
    group_url = create_group 'testgroup'
    prin_url = get_principal_uri @creds[:username]

    set_group_members group_url, prin_url
    assert_group_members group_url, prin_url

    response = @request.delete group_url, admincreds
    assert_equal '204', response.status
  end

  def test_adding_group_to_itself_fails
    group_url = create_group 'testgroup'

    excep = assert_raise(Test::Unit::AssertionFailedError) do
      set_group_members group_url, group_url
    end
    assert_equal "<\"200\"> expected but was\n<\"409\">.", excep.message
    
    excep = assert_raise(Test::Unit::AssertionFailedError) do
      prin_url = get_principal_uri(@creds[:username])
      set_group_members group_url, group_url, prin_url
    end
    assert_equal "<\"200\"> expected but was\n<\"409\">.", excep.message

    assert_group_members group_url

    response = @request.delete group_url, admincreds
    assert_equal '204', response.status
  end

  def test_simple_transitive_membership_w_acls
    group1_url = create_group 'testgroup1'
    group2_url = create_group 'testgroup2'

    # add test1 user to testgroup2
    prin_url = get_principal_uri @creds[:username]
    set_group_members group2_url, prin_url

    @request.delete '/home/test2/testcol', testcreds

    # grant testgroup1 privileges to bind to /home/test2
    ace = RubyDav::Ace.new(:grant, group1_url, false, :bind)
    acl = add_ace_and_set_acl '/home/test2/', ace, testcreds

    # make test1 user create a collection in /home/test2
    response = @request.mkcol '/home/test2/testcol'
    assert_equal '403', response.status

    # add testgroup2 to testgroup1. test1 user should indirectly become a member of testgroup1
    set_group_members group1_url, group2_url

    # make test1 user retry creating a collection in /home/test2
    response = @request.mkcol '/home/test2/testcol'
    # should succeed this time
    assert_equal '201', response.status

    # test1 doesn't have unbind. so deleting should fail
    response = @request.delete '/home/test2/testcol'
    assert_equal '403', response.status

    # grant testgroup1 unbind privileges on /home/test2
    ace = RubyDav::Ace.new(:grant, group1_url, false, :unbind)
    acl = add_ace_and_set_acl '/home/test2/', ace, testcreds

    # make test1 user retry deleting
    response = @request.delete '/home/test2/testcol'
    # should succeed this time
    assert_equal '204', response.status

    # remove testgroup2 from testgroup1. test1 user is no longer an indirect member of testgroup1
    set_group_members group1_url

    # make test1 user create a collection in /home/test2
    response = @request.mkcol '/home/test2/testcol'
    # should fail
    assert_equal '403', response.status

    # cleanup
    response = @request.delete group1_url, admincreds
    assert_equal '204', response.status
    response = @request.delete group2_url, admincreds
    assert_equal '204', response.status
  end

  def test_transitively_adding_group_to_itself_fails
    group1_url = create_group 'testgroup1'
    group2_url = create_group 'testgroup2'
    group3_url = create_group 'testgroup3'

    # add testgroup2 to testgroup1
    set_group_members group1_url, group2_url

    # now try to add testgroup1 to testgroup2
    excep = assert_raise(Test::Unit::AssertionFailedError) do
      set_group_members group2_url, group1_url
    end
    assert_equal "<\"200\"> expected but was\n<\"409\">.", excep.message

    # add testgroup3 to testgroup2
    set_group_members group2_url, group3_url

    # now try to add testgroup1 to testgroup3
    excep = assert_raise(Test::Unit::AssertionFailedError) do
      set_group_members group3_url, group1_url
    end
    assert_equal "<\"200\"> expected but was\n<\"409\">.", excep.message

    # cleanup
    [group1_url, group2_url, group3_url].each do |group_url|
      response = @request.delete group_url, admincreds
      assert_equal '204', response.status
    end
  end

  def test_bad_put_user_followed_by_smaller_good_put_user
    response = @request.put_user(get_principal_uri('cartman'), { :new_password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # big put_user that fails
    response = @request.put_user(get_principal_uri('cartman'), { :email => 'manbearpigmanbearpigmanbearpigmanbearpigmanbearpigmanbearpigmanbearpig@southpark.com',:username => 'cartman', :password => 'cartman'})
    assert_equal '400', response.status

    # smaller put_user that should succeed
    response = @request.put_user(get_principal_uri('cartman'), { :email => 'manbearpig@southpark.com', :cur_password => 'cartman', :username => 'cartman', :password => 'cartman'})
    assert_equal '204', response.status

    delete_user 'cartman'
  end

  def test_adding_and_removing_princpals_from_group_simultaneously
    group1_url = create_group 'testgroup1'
    group2_url = create_group 'testgroup2'
    group3_url = create_group 'testgroup3'
    group4_url = create_group 'testgroup4'

    # add testgroup2 and testgroup4 to testgroup1
    set_group_members group1_url, group2_url, group4_url

    # simultaneoulsy add testgroup3 and remove testgroup2 from testgroup1
    set_group_members group1_url, group3_url, group4_url

    assert_group_members group1_url, group3_url, group4_url

    # cleanup
    [group1_url, group2_url, group3_url, group4_url].each do |group_url|
      response = @request.delete group_url, admincreds
      assert_equal '204', response.status
    end
  end

end
