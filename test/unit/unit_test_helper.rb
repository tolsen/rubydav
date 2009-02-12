require 'tempfile'

require 'test/test_helper'

class RubyDavUnitTestCase < RubyDavTestCase
  
  ASSERT_REXML_INDENT=2

  def normalized_rexml_equal(expected, actual) # unit
    document_context = {
      :compress_whitespace => :all,
      :ignore_whitespace_nodes => :all
    }

    normalized_expected = REXML::Document.new(expected, document_context).to_s(ASSERT_REXML_INDENT)
    normalized_actual = REXML::Document.new(actual, document_context).to_s(ASSERT_REXML_INDENT)
    normalized_expected == normalized_actual
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
      principal.printXML xml
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

    @lockdiscovery = <<EOS
  <?xml version="1.0" encoding="utf-8" ?> 
  <D:prop xmlns:D="DAV:"> 
    <D:lockdiscovery> 
      <D:activelock> 
        <D:locktype><D:write/></D:locktype> 
        <D:lockscope><D:exclusive/></D:lockscope> 
        <D:depth>infinity</D:depth> 
        <D:owner> 
          <D:href>http://example.org/~ejw/contact.html</D:href> 
        </D:owner> 
        <D:timeout>Second-604800</D:timeout> 
        <D:locktoken> 
          <D:href
          >urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4</D:href>
        </D:locktoken> 
        <D:lockroot> 
          <D:href
          >http://example.com/workspace/webdav/proposal.doc</D:href>
        </D:lockroot> 
      </D:activelock> 
    </D:lockdiscovery> 
  </D:prop> 
EOS

    # This one is missing D:locktype, a required element
    @bad_lockdiscovery = <<EOS
  <?xml version="1.0" encoding="utf-8" ?> 
  <D:prop xmlns:D="DAV:"> 
    <D:lockdiscovery> 
      <D:activelock> 
        <D:lockscope><D:exclusive/></D:lockscope> 
        <D:depth>infinity</D:depth> 
        <D:owner> 
          <D:href>http://example.org/~ejw/contact.html</D:href> 
        </D:owner> 
        <D:timeout>Second-604800</D:timeout> 
        <D:locktoken> 
          <D:href
          >urn:uuid:e71d4fae-5dec-22d6-fea5-00a0c91e6be4</D:href>
        </D:locktoken> 
        <D:lockroot> 
          <D:href
          >http://example.com/workspace/webdav/proposal.doc</D:href>
        </D:lockroot> 
      </D:activelock> 
    </D:lockdiscovery> 
  </D:prop> 
EOS
  end
  
end
