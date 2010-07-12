require 'tempfile'

require 'rubygems'
require 'libxml'

require 'test/test_helper'

class RubyDavUnitTestCase < RubyDavTestCase
  
  def xml_equal? expected, actual
    opts = { :options =>
      (LibXML::XML::Parser::Options::NOENT |
       LibXML::XML::Parser::Options::NOBLANKS)# |
      # Debian Lenny is having trouble finding the COMPACT constant
#       LibXML::XML::Parser::Options::COMPACT)
    }
    normalized_expected = LibXML::XML::Document.string(expected, opts).to_s
    normalized_actual = LibXML::XML::Document.string(actual, opts).to_s

    return normalized_expected == normalized_actual
  end
  
  
  def create_ace_principal_xml principal
    if (Symbol === principal) && (principal != :all) && (principal != :self) &&
        (principal != :authenticated) && (principal != :unauthenticated)
      principal = RubyDav::PropKey.strictly_prop_key principal
    end
    
    if Symbol === principal
      principal_xml = "<D:#{principal.to_s}/>"
    elsif RubyDav::PropKey === principal
      property_xml = String.new
      xml = Builder::XmlMarkup.new(:indent => 2, :target => property_xml)
      principal.to_xml xml
      principal_xml = "<D:property>#{property_xml}</D:property>"
    else
      principal_xml = "<D:href>#{principal.to_s}</D:href>"
    end
  end

  def create_ace_xml(principal, action, privileges, inherited, protected)
    principal_xml = create_ace_principal_xml principal
    protected_xml = protected ? "<D:protected/>" : ""
    inherited_xml = inherited ? "<D:inherited>\n<D:href>http://www.example.org</D:href>\n</D:inherited>" : ""
    body = <<-EOS
<D:ace>
  <D:principal>
    #{principal_xml}
  </D:principal>
  <D:#{action}>
#{privileges.inject("") {|priv_str, privilege| priv_str += "<D:privilege>\n<D:" + privilege.to_s + "/>\n</D:privilege>"}}
  </D:#{action}> #{protected_xml} #{inherited_xml}
</D:ace>
EOS
  end

  def create_acl_xml (*aces)
    ace_str = aces.inject("") do |ace_string, args|
      ace_string += create_ace_xml(*args)
    end
    body = <<EOS
<D:acl xmlns:D = "DAV:">
#{ace_str}
</D:acl>
EOS
  end

  def create_acl_body(*aces)
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + create_acl_xml(*aces)
  end

  def validate_get(request)
    (request.is_a?(Net::HTTP::Get)) && (request.path == @host_path)
  end

  def generate_tmpfile_path
    tmpfile = Tempfile.new 'rubydav_testx'
    tmpfile.close 
    tmpfile.path
  end

  def setup
    super

    supported_privilege_set_str = <<EOS
<D:supported-privilege-set xmlns:D='DAV:'>
  <D:supported-privilege>
    <D:privilege><D:all/></D:privilege>
   <D:abstract/>
    <D:description xml:lang="en">
      Any operation
    </D:description>
    <D:supported-privilege>
      <D:privilege><D:read/></D:privilege>
      <D:description xml:lang="en">
        Read any object
      </D:description>
      <D:supported-privilege>
        <D:privilege><D:read-acl/></D:privilege>
        <D:abstract/>
        <D:description xml:lang="en">Read ACL</D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege> 
          <D:read-current-user-privilege-set/>
        </D:privilege>
        <D:abstract/>
        <D:description xml:lang="en">
          Read current user privilege set property
        </D:description>
      </D:supported-privilege>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:write/></D:privilege>
      <D:description xml:lang="en">
        Write any object
      </D:description>
      <D:supported-privilege>
        <D:privilege><D:write-acl/></D:privilege>
        <D:description xml:lang="en">
          Write ACL
        </D:description>
        <D:abstract/>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:write-properties/></D:privilege>
        <D:description xml:lang="en">
          Write properties
        </D:description>
      </D:supported-privilege>
      <D:supported-privilege>
        <D:privilege><D:write-content/></D:privilege>
        <D:description xml:lang="en">
          Write resource content
        </D:description>
      </D:supported-privilege>
    </D:supported-privilege>
    <D:supported-privilege>
      <D:privilege><D:unlock/></D:privilege>
      <D:description xml:lang="en">
        Unlock resource
      </D:description>
    </D:supported-privilege>
  </D:supported-privilege>
</D:supported-privilege-set>
EOS

    @supported_privilege_set_elem =
      LibXML::XML::Document.string(supported_privilege_set_str).root

    @all_priv = RubyDav::PropKey.get 'DAV:', 'all'
    @read_priv = RubyDav::PropKey.get 'DAV:', 'read'
    @read_cups_priv =
      RubyDav::PropKey.get 'DAV:', 'read-current-user-privilege-set'
    @read_acl_priv = RubyDav::PropKey.get 'DAV:', 'read-acl'
    @write_priv = RubyDav::PropKey.get 'DAV:', 'write'
    @write_acl_priv = RubyDav::PropKey.get 'DAV:', 'write-acl'
    @write_content_priv = RubyDav::PropKey.get 'DAV:', 'write-content'
    @write_properties_priv = RubyDav::PropKey.get 'DAV:', 'write-properties'
    @unlock_priv = RubyDav::PropKey.get 'DAV:', 'unlock'

    @acl_pk = RubyDav::PropKey.get 'DAV:', 'acl'
    @displayname_pk = RubyDav::PropKey.get 'DAV:', 'displayname'
    @getcontentlength_pk = RubyDav::PropKey.get 'DAV:', 'getcontentlength'
    @resourcetype_pk = RubyDav::PropKey.get 'DAV:', 'resourcetype'
  end

  def body_root_element body
    return LibXML::XML::Document.string(body).root
  end

  def validate_propfind(request,depth,body, url_path = @url_path)
    (request.is_a?(Net::HTTP::Propfind)) &&
      (request.path == url_path) &&
      (request['depth'].downcase == depth.to_s.downcase) &&
      (xml_equal?(body, request.body_stream.read))
  end

  def bmark name, value, owner, url = nil
    RubyDav::Bitmark.new name, value, owner, url
  end
  
end
