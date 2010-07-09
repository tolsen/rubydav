class ResponseBuilder
  def construct_multistatus_from_responses(responses,description="")
    body = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<D:multistatus xmlns:D = "DAV:">
#{responses.to_s}
<D:responsedescription>#{description.to_s}</D:responsedescription>
</D:multistatus> 
EOS
  end
  
  def construct_href_status_response(status,*urls)
    body = <<EOS
<D:response>
#{(urls.map {|url| construct_href(url)}).to_s}
#{construct_status(status)}
</D:response>
EOS
  end
  
  def construct_href(url)
    body = "<D:href>#{url.to_s}</D:href>"
  end
  
  def construct_status(status)
    body = "<D:status>HTTP/1.1 #{status.to_s}</D:status>"
  end
  
  def construct_href_propstat_response(url,propstats)
    body = <<EOS
<D:response>
#{construct_href(url)}
#{propstats.to_s}
</D:response>
EOS
  end

  def construct_propstat(status, dav_error, *props)
    body = <<EOS
<D:propstat>
<D:prop>
#{props.map {|(name,namespace,value)| construct_prop(name,namespace,value)}.to_s}
</D:prop>
#{construct_status(status)}
#{construct_dav_error(dav_error)}
</D:propstat>
EOS
  end

  def construct_mkcol_response(propstats)
    propstats_txt = propstats.map{|status, dav_error, props| construct_propstat(status, dav_error, *props)}.to_s
#    puts propstats_txt
    body = <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<D:mkcol-response xmlns:D = "DAV:">
#{propstats_txt}
</D:mkcol-response>
EOS
  end

  def construct_dav_error(dav_error)
    return nil if dav_error.nil?
    body = "<D:error><D:#{dav_error.condition}/></D:error>"
  end
  
  def construct_prop(name,namespace,value)
    if (RubyDav::Acl === value)
      body = String.new
      xml = Builder::XmlMarkup.new(:indent => 2, :target => body)
      value.to_xml xml
    else
      body = <<EOS
<D:#{name.to_s} xmlns:D = "#{namespace.to_s}">#{value.to_s}</D:#{name.to_s}>
EOS
    end
  end
  
  def construct_cups_prop(*privileges)  
    value = (privileges.map {|privilege| construct_privilege(privilege)}).to_s
    ["current-user-privilege-set","DAV:",value]
  end
  
  def construct_privilege(privilege)
    "<D:privilege><D:#{privilege.to_s}/></D:privilege>"
  end
  
  def construct_propfindcups_response(urlhash,description = "")
    responses = urlhash.map do |url,(status, dav_error, privileges)|
      prop = construct_cups_prop(*privileges)
      propstat = construct_propstat(status, dav_error, prop)
      construct_href_propstat_response(url,propstat)
    end
    construct_multistatus_from_responses(responses,description)
  end
  
  def construct_propfindacl_response(urlhash,description = "")
    responses = urlhash.map do |url,(status, dav_error, acl)|
      propstat = construct_propstat(status, dav_error, ["acl","DAV:",acl])
      construct_href_propstat_response(url,propstat)
    end
    construct_multistatus_from_responses(responses,description)
  end
  
  
  def construct_multiprop_response(urlhash,description = "")
    responses = urlhash.map do |url,propstats|
      construct_href_propstat_response(url,propstats.map{|status, dav_error, props| construct_propstat(status, dav_error, *props)})
    end
    construct_multistatus_from_responses(responses, description)
  end
  
  def construct_copy_response(statuslist,description = "")
    responses = statuslist.map do |(status,urls)|
      construct_href_status_response(status,*urls)
    end
    construct_multistatus_from_responses(responses, description)
  end
end

