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

  def test_extended_mkcol_for_creating_group
    @request.delete '/groups/new_group', admincreds
    ace = RubyDav::Ace.new(:grant, :authenticated, false, :bind)
    acl = add_ace_and_set_acl '/groups', ace, admincreds


    ob = Object.new
    def ob.target!
      "<D:principal/>"
    end
    response = @request.mkcol_ext '/groups/new_group', {:resourcetype => ob}
    assert_equal '201', response.status
    assert_equal '200', response.statuses(:resourcetype)

    response = @request.propfind('/groups/new_group', 0, :resourcetype)
    assert_match 'D:principal', response[:resourcetype]

    @request.delete '/groups/new_group', admincreds
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
