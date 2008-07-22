require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavBasicTest < Test::Unit::TestCase
  include WebDavTestSetup
  def setup
    webdavtestsetup
  end

  def test_limebits_email_property
    lb_email_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'email')
    prin_uri = get_principal_uri(@creds[:username])
    
    response = @request.proppatch(prin_uri, { lb_email_propkey => 'foo@bar.com' })
    assert_equal '207', response.status
    assert !response.error?
    assert response.propertyhash[lb_email_propkey]

    response = @request.propfind(prin_uri, 0, lb_email_propkey)
    assert_equal '207', response.status
    assert_equal 'foo@bar.com', response.propertyhash[lb_email_propkey].strip
    
    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response.statuses(lb_email_propkey)
  end

  def test_limebits_read_private_properties_priv
    lb_email_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'email')
    prin_uri = get_principal_uri(@creds[:username])
    
    response = @request.proppatch(prin_uri, { lb_email_propkey => 'foo@bar.com' })
    assert_equal '207', response.status
    assert !response.error?
    assert response.propertyhash[lb_email_propkey]

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response.statuses(lb_email_propkey)

    lb_read_priv_properties_key = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'read-private-properties')
    # grant test user all privileges on coll
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, lb_read_priv_properties_key)
    acl = add_ace_and_set_acl prin_uri, ace

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '200', response.statuses(lb_email_propkey)
    assert_equal 'foo@bar.com', response.propertyhash[lb_email_propkey].strip

    acl.shift
    response = @request.acl prin_uri, acl
    assert_equal '200', response.status

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response.statuses(lb_email_propkey)
  end

  def test_dav_read_private_properties_priv
    prin_uri = get_principal_uri(@creds[:username])

    acl = get_acl prin_uri
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, :"read-priv-properties")
    acl.unshift ace

    response = @request.acl(prin_uri, acl)
    # expect 'not-supported-privilege' error
    assert_dav_error response, "not-supported-privilege"

  end

  def test_lb_domain_map_property
    new_coll 'new_root'
    new_file 'new_root/testfile', StringIO.new("test")

    lb_domain_map_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'domain-map')
    prin_uri = get_principal_uri(@creds[:username])
    domain_map = String.new
    xml ||= ::Builder::XmlMarkup.new(:indent => 2, :target => domain_map)
    xml.lb 'domain-map-entry'.to_sym, "xmlns:lb" => "http://limebits.com/ns/1.0/" do
      xml.lb(:domain, altdomain)
      xml.lb(:path, '/new_root')
    end
  
    response = @request.proppatch(prin_uri, { lb_domain_map_propkey => xml })
    assert_equal '207', response.status
    assert !response.error?
    assert response.propertyhash[lb_domain_map_propkey]

    response = @request.propfind(prin_uri, 0, lb_domain_map_propkey)
    assert_equal '207', response.status
    assert !response.error?

    assert_xml_matches response.body do |xml|
      xml.xmlns! 'DAV:'
      xml.xmlns! :lb => 'http://limebits.com/ns/1.0/'
      xml.multistatus do
        xml.response do
          xml.href prin_uri
          xml.propstat do
            xml.prop do
              xml.lb 'domain-map'.to_sym do
                xml.lb 'domain-map-entry'.to_sym do
                  xml.lb :domain, altdomain
                  xml.lb :path, '/new_root'
                end
              end
            end
            xml.status /HTTP\/1.1\s+200/
          end
        end
      end
    end

    # cleanup
    delete_coll 'new_root'
    response = @request.proppatch(prin_uri, { lb_domain_map_propkey => '' })
    assert_equal '207', response.status
  end

  def altdomain
    hosturi = URI.parse(@host)
    "localhost:" + hosturi.port.to_s
  end
end
