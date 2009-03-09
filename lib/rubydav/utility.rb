require 'rexml/document'
require 'stringio'
require 'uri'

require File.dirname(__FILE__) + '/errors'

module RubyDav

  class << self
    def getrequestclass(httpmethod)
      method = case httpmethod.to_s
               when /^propfind/ : :propfind
               when /^report/ : :report
               when /^mkcol/ : :mkcol
               else httpmethod
               end

      Net::HTTP.const_get(method.to_s.capitalize)
    end

    def parse_status(str)
      return $3 if str =~ /\A(HTTP|Webdav)(?:\/(\d+\.\d+))?\s+(\d\d\d)\s*(.*)\z/
      raise BadResponseError
    end
    
    def remove_trailing_slashes(str)
      str.sub! /(\/)+$/, '' if str
      str
    end
    
    def uri_path(uri)
      File.expand_path(URI.parse(uri).path,"/")
    end

    # yields xml (builder) and namespaces
    # returns output if new xml builder was created
    def buildXML xml = nil, &block
      output = nil
      namespaces = []
      
      if xml.nil?
        output = ""
        xml = Builder::XmlMarkup.new(:indent => 2, :target => output)
        namespaces << { 'xmlns:D' => 'DAV:' }
      end
      
      yield xml, namespaces if block_given?
      return output
    end

    # does REXML::XPath.first but with default namespace set to DAV:
    def xpath_first elem, path, namespaces = {}
      namespaces = { '' => 'DAV:' }.merge namespaces
      return REXML::XPath.first(elem, path, namespaces)
    end

    # does REXML::XPath.match but with default namespace set to DAV:
    def xpath_match elem, path, namespaces = {}
      namespaces = { '' => 'DAV:' }.merge namespaces
      return REXML::XPath.match(elem, path, namespaces)
    end

    # runs xpath_first against the path with "/text()" appended
    # and converts to String
    # return nil if not found
    def xpath_text elem, path, namespaces = {}
      text_node = xpath_first elem, "#{path}/text()", namespaces
      return text_node.nil? ? nil : text_node.to_s
    end
    
    def assert_elem_name elem, name, namespace = 'DAV:'
      raise ArgumentError unless
        elem.namespace == namespace && elem.name == name
    end

    def build_xml_stream &block
      requestbody = String.new
      xml = RubyDav::XmlBuilder.generate requestbody
      yield xml
      return StringIO.new(requestbody)
    end
    
  end

end
