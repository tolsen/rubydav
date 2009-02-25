require 'test/unit'
require 'test/integration/webdavtestsetup'

class WebDavLimeBitsTest < Test::Unit::TestCase
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
    assert_equal '200', response[lb_email_propkey].status

    response = @request.propfind(prin_uri, 0, lb_email_propkey)
    assert_equal '207', response.status
    assert_equal 'foo@bar.com', response[lb_email_propkey].inner_value.strip
    
    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response[lb_email_propkey].status
  end

  def test_limebits_read_private_properties_priv
    lb_email_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'email')
    prin_uri = get_principal_uri(@creds[:username])
    
    response = @request.proppatch(prin_uri, { lb_email_propkey => 'foo@bar.com' })
    assert_equal '207', response.status
    assert !response.error?
    assert_equal '200', response[lb_email_propkey].status

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response[lb_email_propkey].status

    lb_read_priv_properties_key = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'read-private-properties')
    # grant test user all privileges on coll
    ace = RubyDav::Ace.new(:grant, test_principal_uri, false, lb_read_priv_properties_key)
    acl = add_ace_and_set_acl prin_uri, ace

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '200', response[lb_email_propkey].status
    assert_equal 'foo@bar.com', response[lb_email_propkey].inner_value.strip

    acl.shift
    response = @request.acl prin_uri, acl
    assert_equal '200', response.status

    response = @request.propfind(prin_uri, 0, lb_email_propkey, testcreds)
    assert_equal '207', response.status
    assert_equal '403', response[lb_email_propkey].status
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

  def test_null_lb_domain_map

    lb_domain_map_propkey = RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'domain-map')
    prin_uri = get_principal_uri(@creds[:username])

    response = @request.propfind(prin_uri, 0, lb_domain_map_propkey)
    assert_equal '207', response.status
    assert_equal '404', response[lb_domain_map_propkey].status

  end

  def test_lb_domain_map_property
    new_coll 'new_root'
    new_file 'new_root/testfile', StringIO.new("test")

    prin_uri = get_principal_uri(@creds[:username])

    # test for single domain-map-entry
    domain_map = [[altdomain, '/new_root']]
    set_and_test_domain_map prin_uri, domain_map

    # test for multiple domain-map-entries
    domain_map = [[altdomain2, '/'], [altdomain, '/new_root']]
    set_and_test_domain_map prin_uri, domain_map

    # cleanup
    delete_coll 'new_root'
    response = @request.proppatch(prin_uri, { lb_domain_map_propkey => '' })
    assert_equal '207', response.status
  end

  def test_rename_updates_mime_type
    new_file 'test', StringIO.new('#include <stdio.h>')

    response = @request.move('test', 'test.html', true)
    assert_equal '201', response.status
    
    response = @request.get('test.html')
    assert_equal '200', response.status
    assert_equal 'text/html', response.headers["content-type"][0]

    delete_file 'test.html'
  end

  def set_and_test_domain_map uri, domain_map
    xml = get_domain_map_xml domain_map
    response = @request.proppatch(uri, { lb_domain_map_propkey => xml })
    assert_equal '207', response.status
    assert !response.error?
    assert_equal '200', response[lb_domain_map_propkey].status

    response = @request.propfind(uri, 0, lb_domain_map_propkey)
    assert_equal '207', response.status
    assert !response.error?

    assert_xml_matches response.body do |xml|
      xml.xmlns! 'DAV:'
      xml.xmlns! :lb => 'http://limebits.com/ns/1.0/'
      xml.multistatus do
        xml.response do
          xml.href uri
          xml.propstat do
            xml.prop do
              xml.lb 'domain-map'.to_sym do
                domain_map.each do |domain, path| 
                  xml.lb :'domain-map-entry' do
                    xml.lb(:domain, domain)
                    xml.lb(:path, path)
                  end
                end
              end
            end
            xml.status /HTTP\/1.1\s+200/
          end
        end
      end
    end
  end

  def altdomain
    hosturi = URI.parse(@host)
    "localhost:" + hosturi.port.to_s
  end

  def altdomain2
    hosturi = URI.parse(@host)
    "127.0.0.1:" + hosturi.port.to_s
  end

  def lb_domain_map_propkey
    RubyDav::PropKey.get('http://limebits.com/ns/1.0/', 'domain-map')
  end

  def get_domain_map_xml domain_map
    target = String.new
    xml = ::Builder::XmlMarkup.new(:indent => 2, :target => target)

    domain_map.each do |domain, path|
      xml.lb 'domain-map-entry'.to_sym, "xmlns:lb" => "http://limebits.com/ns/1.0/" do
        xml.lb(:domain, domain)
        xml.lb(:path, path)
      end
    end

    return xml
  end
end
