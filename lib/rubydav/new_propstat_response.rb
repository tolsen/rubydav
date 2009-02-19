require 'lib/rubydav/response.rb'

module RubyDav

  # For mulistatus responses that return individual DAV:response elements with
  # DAV:propstat elements
  class NewPropstatResponse < MultiStatusResponse
    
    attr_reader :resources
    
    def initialize(url, status, headers, body, resources)
      super(url, status, headers, body, nil)
      @resources = resources
    end

    def unauthorized?
      @unauthorized ||= @resources.values.any? do |properties|
        properties.values.any? { |r| r.status == '401' }
      end
      
      return @unauthorized
    end

    def self.create(url, status, headers, body, method)
      resources = self.parse_body body
      return self.new url, status, headers, body, resources
    end

    private
    def self.parse_propstats response
      propstats = REXML::XPath.match(response, "D:propstat", {"D" => "DAV:"})
      propstats.each do |propstat|
        status_elem = REXML::XPath.first(propstat, "D:status", {"D" => "DAV:"})
        status = RubyDav.parse_status(status_elem.text)
        dav_error_elem = REXML::XPath.first(propstat, "D:error", {"D" => "DAV:"})
        dav_error = DavError.parse_dav_error(dav_error_elem)
        props =  parse_prop(REXML::XPath.first(propstat, "D:prop", {"D" => "DAV:"}))
        yield(status, dav_error, props)
      end
    end

    def self.parse_body(body)
      root = REXML::Document.new(body).root
      urlhash = {}
      raise BadResponseError unless (root.namespace == "DAV:" && root.name == "multistatus")
      responses = REXML::XPath.match(root, "D:response", {"D" => "DAV:"})
      responses.each do |response|
        href_elem = REXML::XPath.first(response, "D:href", {"D" => "DAV:"})
        href = href_elem.text

        propstats = REXML::XPath.match(response, "D:propstat", {"D" => "DAV:"})
        urlhash[href] ||= {}
        self.parse_propstats(response) do |status, dav_error, props|
          props.each do |pk, element|
            urlhash[href][pk] = PropertyResult.new pk, status, element, dav_error
          end
        end
      end
      return urlhash
    end

    def self.parse_prop(prop_element)
      prophash = {}
      prop_element.each_element do |property|
        propkey = PropKey.get(property.namespace, property.name)
        prophash[propkey] = property
      end
      return prophash
    end

  end

end
