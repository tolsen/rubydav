require 'stringio'
require 'uri'

require 'rubygems'
require 'libxml'

require File.dirname(__FILE__) + '/errors'

# Debian Lenny's version of libxml complains too much that
# DAV: is not a valid URI
LibXML::XML.default_warnings = false

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

    @@gc_block_count = 0
    def ensure_garbage_collection &block
      @@gc_block_count += 1
      yield
    ensure
      @@gc_block_count -= 1
      GC.start if @@gc_block_count.zero?
    end

    # does find, but with D => DAV: added to nslist.
    #
    # yields instead of returning XPath object as to not trigger
    # libxml segfault.
    # See http://libxml.rubyforge.org/rdoc/classes/LibXML/XML/Document.html#M000471
    def find node, xpath, nslist = nil, &block
      yield node.find(xpath, davify_nslist(nslist))
      return nil
    end

    # does find_first, but with D => DAV: added to nslist
    def find_first node, xpath, nslist = nil
      return node.find_first(xpath, davify_nslist(nslist))
    end

    # runs find_first against the xpath with "/text()" appended
    # and converts to String
    # return nil if not found
    def find_first_text node, xpath, nslist = nil
      text_node = find_first node, "#{xpath}/text()", nslist
      return text_node.nil? ? nil : text_node.to_s
    end

    # creates a copy of each child before doing to_s
    # so that namespaces are properly declared
    def inner_xml_copy node, options = {}
      return (node.map { |n| to_s_copy n, options }.join '')
    end

    def namespace_href node
      return node.namespaces.namespace.href
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

    # wraps methods in an ensure_garbage_collection() block
    # to make sure garbage collection is done and to also minimize
    # the number of garbage collections
    def gc_protect klass, *methods
      methods.each do |method|
        klass.module_eval <<-"end;"
          unless instance_methods.include? :__#{method.to_i}__
            alias_method :__#{method.to_i}__, :#{method.to_s}
            private :__#{method.to_i}__
            def #{method.to_s}(*args, &block)
              RubyDav.ensure_garbage_collection do
                return __#{method.to_i}__(*args, &block)
              end
            end
          end
        end;
      end
    end

    # to_s of a copy
    # useful for getting all namespaces declared
    def to_s_copy node, options = {}
      node.copy(true).to_s options
    end
    
  end


  class << self
    include Utility
  end

  module Utility
    RubyDav.gc_protect self, :find, :find_first
  end

end
