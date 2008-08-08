require 'test/unit'
require 'lib/rubydav'
require 'test/integration/webdavtestsetup'

class LimestonePrincipalTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def put_user args
    username = args[:username]
    passwd = args[:password]
    cur_passwd = args[:cur_password]
    displayname = args[:displayname]
    email = args[:email]
    creds = args[:creds] || {}

    requestbody = String.new
    xml ||= RubyDav::XmlBuilder.generate(requestbody)
    xml.L(:"user", {"xmlns:L" => "http://limebits.com/ns/1.0/", "xmlns:D" => "DAV:"}) do
      xml.D(:displayname, displayname) if displayname
      xml.L(:password, passwd) if passwd
      xml.L(:cur_password, cur_passwd) if cur_passwd
      xml.L(:email, email) if email
    end
    bodystream = StringIO.new(requestbody)
    
    response = @request.put(get_principal_uri(username), bodystream, creds)
  end

  def delete_user user
    response = @request.delete(get_home_path(user), admincreds)
    assert_equal '204', response.status

    response = @request.delete(get_principal_uri(user), admincreds)
    assert_equal '204', response.status
  end

  def test_put_for_creating_user
    response = put_user({:username=> 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    delete_user 'cartman'
  end

  def test_put_for_updating_displayname
    response = put_user({:username => 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status
    
    response = put_user({:username => 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '403', response.status

    # update displayname
    response = put_user({:username => 'cartman', :displayname => 'Eric Cartman',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '204', response.status

    response = @request.propfind(get_principal_uri('cartman'), 0, :displayname )
    assert_equal '207', response.status
    assert_equal 'Eric Cartman', response[:displayname].strip

    delete_user 'cartman'
  end

  def test_put_for_updating_password_requires_current_password
    response = put_user({:username => 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # try changing password without old password
    response = put_user({:username => 'cartman', :password => 'manbearpig',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '400', response.status

    response = put_user({:username => 'cartman', :password => 'manbearpig', :cur_password => 'cartman',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '204', response.status

    delete_user 'cartman'
  end

  def test_put_for_updating_email_requires_current_password
    response = put_user({:username => 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # try changing email without password
    response = put_user({:username => 'cartman', :email => 'manbearpig@southpark.com',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '400', response.status

    response = put_user({:username => 'cartman', :email => 'manbearpig@southpark.com', :cur_password => 'cartman',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '204', response.status

    delete_user 'cartman'
  end

  def create_group group_name
    group_url = "/groups/#{group_name}"

    @request.delete group_url, admincreds
    ace = RubyDav::Ace.new(:grant, :authenticated, false, :bind)
    acl = add_ace_and_set_acl '/groups', ace, admincreds

    ob = Object.new
    def ob.target!
      "<D:principal/>"
    end
    response = @request.mkcol_ext group_url, {:resourcetype => ob}
    assert_equal '201', response.status
    assert_equal '200', response.statuses(:resourcetype)
    group_url
  end

  def test_extended_mkcol_for_creating_group
    group_url = create_group 'testgroup'

    response = @request.propfind(group_url, 0, :resourcetype)
    assert_match 'D:principal', response[:resourcetype]

    @request.delete group_url, admincreds
  end

  def test_adding_user_to_group
    group_url = create_group 'testgroup'

    prin_uri = get_principal_uri(@creds[:username], baseuri)

    hrefxml = ::Builder::XmlMarkup.new()
    hrefxml.D(:href, prin_uri)

    response = @request.proppatch(group_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert !response.error?
    assert response[:"group-member-set"]

    response = @request.propfind(group_url, 0, :"group-member-set")
    assert_equal '207', response.status

    assert_xml_matches response[:"group-member-set"] do |xml|
      xml.xmlns! 'DAV:'
      xml.href prin_uri
    end

    response = @request.delete group_url, admincreds
    assert_equal '204', response.status
  end

  def test_adding_group_to_itself_fails
    group_url = create_group 'testgroup'

    group_uri = baseuri + group_url

    hrefxml = ::Builder::XmlMarkup.new()

    hrefxml.D(:href, group_uri)
    response = @request.proppatch(group_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert response.error?
    assert_equal '409', response.statuses(:"group-member-set")

    prin_uri = get_principal_uri(@creds[:username], baseuri)
    hrefxml.D(:href, prin_uri)
    response = @request.proppatch(group_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert response.error?
    assert_equal '409', response.statuses(:"group-member-set")

    response = @request.propfind(group_url, 0, :"group-member-set")
    assert_equal '207', response.status
    assert_equal "", response[:"group-member-set"]

    response = @request.delete group_url, admincreds
    assert_equal '204', response.status
  end

  def test_simple_transitive_membership_w_acls
    group1_url = create_group 'testgroup1'
    group2_url = create_group 'testgroup2'

    group1_uri = baseuri + group1_url
    group2_uri = baseuri + group2_url

    hrefxml = ::Builder::XmlMarkup.new()

    # add test1 user to testgroup2
    prin_uri = get_principal_uri(@creds[:username], baseuri)
    hrefxml.D(:href, prin_uri)

    response = @request.proppatch(group2_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert !response.error?
    assert_equal '200', response.statuses(:"group-member-set")

    @request.delete '/home/test2/testcol', testcreds

    # grant testgroup1 privileges to bind to /home/test2
    ace = RubyDav::Ace.new(:grant, group1_uri, false, :bind)
    acl = add_ace_and_set_acl '/home/test2/', ace, testcreds

    # make test1 user create a collection in /home/test2
    response = @request.mkcol '/home/test2/testcol'
    assert_equal '403', response.status

    # add testgroup2 to testgroup1. test1 user should indirectly become a member of testgroup1
    hrefxml = ::Builder::XmlMarkup.new()
    hrefxml.D(:href, group2_uri)
    response = @request.proppatch(group1_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert !response.error?
    assert_equal '200', response.statuses(:"group-member-set")

    # make test1 user retry creating a collection in /home/test2
    response = @request.mkcol '/home/test2/testcol'
    # should succeed this time
    assert_equal '201', response.status

    # test1 doesn't have unbind. so deleting should fail
    response = @request.delete '/home/test2/testcol'
    assert_equal '403', response.status

    # grant testgroup1 unbind privileges on /home/test2
    ace = RubyDav::Ace.new(:grant, group1_uri, false, :unbind)
    acl = add_ace_and_set_acl '/home/test2/', ace, testcreds

    # make test1 user retry deleting
    response = @request.delete '/home/test2/testcol'
    # should succeed this time
    assert_equal '204', response.status

    # remove testgroup2 from testgroup1. test1 user is no longer an indirect member of testgroup1
    response = @request.proppatch(group1_url, {:"group-member-set" => "" });
    assert_equal '207',response.status
    assert !response.error?
    assert_equal '200', response.statuses(:"group-member-set")

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

    group1_uri = baseuri + group1_url
    group2_uri = baseuri + group2_url

    # add testgroup2 to testgroup1
    hrefxml = ::Builder::XmlMarkup.new()

    hrefxml.D(:href, group2_uri)
    response = @request.proppatch(group1_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    assert_equal '200', response.statuses(:"group-member-set")

    # now try to add testgroup1 to testgroup2
    hrefxml = ::Builder::XmlMarkup.new()
    hrefxml.D(:href, group1_uri)
    response = @request.proppatch(group2_url, {:"group-member-set" => hrefxml });
    assert_equal '207',response.status
    # assert failure
    assert response.error?
    assert_equal '409', response.statuses(:"group-member-set")

    # cleanup
    response = @request.delete group1_url, admincreds
    assert_equal '204', response.status
    response = @request.delete group2_url, admincreds
    assert_equal '204', response.status
  end

  def test_bad_put_user_followed_by_smaller_good_put_user
    response = put_user({:username=> 'cartman', :password => 'cartman', :displayname => 'Eric', :email => 'cartman@southpark.com'})
    assert_equal '201', response.status

    # big put_user that fails
    response = put_user({:username => 'cartman', :email => 'manbearpigmanbearpigmanbearpigmanbearpigmanbearpigmanbearpigmanbearpig@southpark.com',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '400', response.status
    
    # smaller put_user that should succeed
    response = put_user({:username => 'cartman', :email => 'manbearpig@southpark.com', :cur_password => 'cartman',
                          :creds => {:username => 'cartman', :password => 'cartman'}})
    assert_equal '204', response.status

    delete_user 'cartman'
  end
end
