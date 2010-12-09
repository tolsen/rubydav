require 'stringio'
require 'uri'

require 'rubygems'
require 'nokogiri'

require File.dirname(__FILE__) + '/errors'

module RubyDav

  module Utility
    
    def get_request_class(httpmethod)
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
      namespaces = {}
      
      if xml.nil?
        output = ""
        xml = Builder::XmlMarkup.new(:indent => 2, :target => output)
        namespaces['xmlns:D'] = 'DAV:'
      end
      
      yield xml, namespaces if block_given?
      return output
    end

    
    def davify_nslist nslist
      return case nslist
             when nil: ['D:DAV:']
             when Array: nslist.push 'D:DAV:'
             when Hash: { 'D' => 'DAV:' }.merge nslist
             end
    end

    @@generalize_principal_rx =
      /^#{URI::REGEXP::PATTERN::SCHEME}:\/\/#{URI::REGEXP::PATTERN::AUTHORITY}/

    # removes hostname from principal
    def generalize_principal principal
      return principal.sub(@@generalize_principal_rx, '')
    end

    # creates a copy of each child before doing to_s
    # so that namespaces are properly declared
    def inner_xml_copy node, options = {}
      return (node.children.map { |n| to_s_copy n, options }.join '')
    end

    def namespace_href node
      ns = node.namespace
      return ns.nil? ? nil : ns.href
    end
    
    def assert_elem_name elem, name, namespace = 'DAV:'
      raise ArgumentError unless node_has_name? elem, name, namespace
    end

    def build_xml_stream &block
      requestbody = String.new
      xml = RubyDav::XmlBuilder.generate requestbody
      yield xml
      return StringIO.new(requestbody)
    end

    def node_has_name? node, name, ns = 'DAV:'
      !node.nil? && namespace_href(node) == ns && node.name == name
    end

    def dav_elements node
      elements = []
      each_dav_element(node) { |e| elements << e }
      return elements
    end

    def dav_elements_hash node, *names
      hsh = {}
      each_dav_element node do |e|
        hsh[e.name] = e if names.include? e.name
      end
      return hsh
    end

    def each_dav_element node, &block
      each_element_in_namespace node, 'DAV:', &block
    end

    def each_element_in_namespace node, ns, &block
      node.element_children.each do |e|
        yield e if namespace_href(e) == ns
      end
    end

    def each_element_named node, name, ns = 'DAV:', &block
      node.element_children.each do |e|
        yield e if namespace_href(e) == ns && e.name == name
      end
    end

    def element_to_propkey elem
      return PropKey.get(RubyDav.namespace_href(elem), elem.name)
    end

    def elements_named node, name, ns = 'DAV:'
      elements = []
      each_element_named(node, name, ns) { |e| elements << e }
      return elements
    end

    def first_element node
      node.element_children.each { |n| return n }
      return nil
    end

    def first_element_named node, name, ns = 'DAV:'
      each_element_named(node, name, ns) { |n| return n }
      return nil
    end

    # follows names until it comes to element
    def get_dav_descendent node, *names
      return node if names.empty? || node.nil?
      next_node = first_element_named node, names.shift
      return get_dav_descendent(next_node, *names)
    end

    # to_s of a copy
    # useful for getting all namespaces declared
    def to_s_copy node, options = {}
      node.dup.to_xml options
    end

    def privilege_elements_to_propkeys parent_elem
      propkeys = []
      RubyDav.each_element_named parent_elem, 'privilege' do |privilege_node|
        seen_child = false
        privilege_node.element_children.each do |e|
          raise "cannot have more than one privilege inside <privilege>" if seen_child
          propkeys << RubyDav.element_to_propkey(e)
          seen_child = true
        end
        raise "privilege node has no child!" unless seen_child
      end
      return propkeys
    end

    # returns root
    def parse_xml str
      Nokogiri::XML::Document.parse(str).root
    end

    def xml_lang node
      lang_attr = node.attribute_with_ns "lang", "http://www.w3.org/XML/1998/namespace"
      return lang_attr.value unless lang_attr.nil?
      return nil if node == node.document.root
      return xml_lang(node.parent)
    end
    
  end


  class << self
    include Utility
  end

end
