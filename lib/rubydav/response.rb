require File.dirname(__FILE__) + '/acl'
require File.dirname(__FILE__) + '/dav_error'
require File.dirname(__FILE__) + '/errors'
require File.dirname(__FILE__) + '/lock_discovery'
require File.dirname(__FILE__) + '/utility'
require File.dirname(__FILE__) + '/sub_response'

module RubyDav

  # Response classes returned when RubyDav.method is called
  # base Response class
  class Response

    include Utility

    attr_reader :url

    # HTTP status code
    attr_reader :status

    attr_reader :headers

    # returns true if 401 or 207 which contains a 401
    def unauthorized?
      @unauthorized
    end
    
    # date on server at time of response
    def date
      if @headers && Array === @headers["date"] && @headers["date"].size > 0
        @headers["date"][0]
      end
    end
    
    def etag
      etag_hdrs = headers['etag']
      return nil if etag_hdrs.nil? || etag_hdrs.empty?
      return etag_hdrs.first
    end

    def self.create(url, status, headers, body, method)
      self.new(url,status,headers)
    end

    def initialize(url, status, headers)
      @status = status
      @url = url
      @headers = headers
      @unauthorized = false if @unauthorized.nil?
    end

    def get_fields field
      v = headers[field.downcase]
      if v.nil?
        return []
      elsif v.is_a? Array
        return v
      else
        return [v]
      end
    end

    def get_field field
      v = headers[field.downcase]
      if v.nil?
        return v
      elsif v.is_a? Array
        return v[0]
      else
        return v
      end
    end

    class << self
      include Utility
    end
    
  end


  # successful response class, 2xx series
  class SuccessfulResponse < Response
    def error?
      false
    end
  end

  # redirect response class, 3xx series
  class RedirectionResponse < Response
    def redirectref
        headers["redirect-ref"][0]
    end

    def location
        headers["location"][0]
    end
  end

  # error response class, 4xx and 5xx series
  class ErrorResponse < Response
    def error?
      true
    end

    class << self

      def xml_content_type? headers
        return (headers['content-type'].any? do |v|
                  v =~ /((^(application|text)\/xml)|\+xml)(\s|;|$)/
                end)
      end
      
      def parse_dav_error headers, body
        derror = nil
        if !body.nil? && xml_content_type?(headers)
          begin
            root = parse_xml body
            derror = DavError.parse root
          rescue Nokogiri::XML::SyntaxError  # possibly not a proper xml body
          end
        end
        return derror
      end
    end
    
  end

  # multistatus response class, status 207. It provides status for multiple
  # independent operations.
  class MultiStatusResponse < Response
    
    attr_reader :description
    attr_reader :body
    
    # hash of href -> SubResponse
    attr_reader :responses
    
    def error?
      [:copy, :lock].include? @method
    end

    def unauthorized?
      @unauthorized ||= responses.values.any? { |r| r.status == '401' }
      return @unauthorized
    end

    class << self
      def create(url,status,headers,body,method)
        responses = {}
        root = parse_xml body

        raise BadResponseError unless node_has_name? root, 'multistatus'
        description = nil

        rd_elem = first_element_named root, 'responsedescription'
        description = rd_elem.nil? ? nil : rd_elem.content

        response_elements = elements_named root, 'response'
        
        raise BadResponseError if response_elements.empty?

        response_elements.each do |response_element|
          children = dav_elements_hash(response_element, 'status', 'error',
                                       'responsedescription', 'location')
          children_text =
            %w(status responsedescription location).inject({}) do |h, k|
            h[k] = children[k].content if children.include? k
            next h
          end

          sub_status = parse_status children_text['status']
          error = DavError.parse children['error']

          each_element_named response_element, 'href' do |href_elem|
            href = href_elem.content
            raise BadResponseError if responses.include? href
            responses[href] =
              SubResponse.new(href, sub_status, error,
                              children_text['description'],
                              children_text['location'])
          end
        end
        
        return MultiStatusResponse.new(url, status, headers, body,
                                       responses, method, description)
      end

    end

    private
    def initialize(url, status, headers, body, responses, method=nil, description=nil)
      @responses = responses || {}
      @body = body
      @method = method
      @description = description
      super(url, status, headers)
    end
  end

  # successful response with body, status 200. According to the request
  # method, the body contains information.
  class OkResponse < SuccessfulResponse
    attr_reader :body

    def self.create(url, status, headers, body, method)
      self.new(url, status, headers, body)
    end

    private
    def initialize(url, status, headers, body)
      @body = body
      super(url, status, headers)
    end
  end

  # successful response class for Lock request, status 200
  class OkLockResponse < OkResponse #:nodoc:
    # returns the lock discovery info inside the response body of a successful
    # lock request

    attr_reader :lock_discovery, :lock_token

    # returns ActiveLock object for this request
    def active_lock
      return nil if @lock_token.nil?
      return @lock_discovery.locks[@lock_token]
    end

    class << self
      
      def create(url, status, headers, body, method)
        lock_discovery = parse_body(body)

        response = new url, status, headers, body, lock_discovery
        return response
      end

      def parse_body(body)
        root = parse_xml body
        
        raise BadResponseError unless node_has_name? root, 'prop'
        ld_elem = first_element_named root, 'lockdiscovery'
        raise BadResponseError if ld_elem.nil?
        return RubyDav::LockDiscovery.from_elem(ld_elem)
      rescue ArgumentError
        raise BadResponseError
      end

    end
    
    private

    def initialize(url, status, headers, body, lock_discovery)
      @lock_discovery = lock_discovery

      # Lock-Token header is not set on lock refreshes
      if headers.include? 'lock-token'
        lt_hdr_vals = headers['lock-token']
        raise BadResponseError unless
          lt_hdr_vals.is_a?(Array) && lt_hdr_vals.size == 1
        @lock_token = lt_hdr_vals[0].sub /^\s*<(.*)>\s*$/, '\1'
      end
      
      super(url, status, headers, body)
    end
  end

  # successful response and new resource created for the request URI, status
  # 201.
  class CreatedResponse < SuccessfulResponse ; end

  # successful response class, status 204. The server has fulfilled the
  # request but does not need to return an entity-body, and might want to
  # return updated metainformation in the form of entity-headers.
  class NoContentResponse < SuccessfulResponse ; end

  # successful response class, status 206
  class PartialContentResponse < SuccessfulResponse #:nodoc
  end

  # successful response class, status 208. It is generally used inside a
  # DAV:propstat response element to indicate that information about the
  # resource has already been reported in a previous DAV:propstat element in
  # that response.
  class AlreadyReportedResponse < SuccessfulResponse ; end

  require 'pp'
  # client error response class, 4xx series
  class ClientErrorResponse < ErrorResponse
    attr_reader :dav_error, :body

    def self.create(url, status, headers, body, method)
      dav_error = parse_dav_error headers, body
      self.new(url, status, headers, body, dav_error)
    end

    def initialize(url, status, headers, body, dav_error=nil)
      @body = body
      @dav_error = dav_error
      super(url, status, headers)
    end
  end

  # server error response class, 5xx series
  class ServerErrorResponse < ErrorResponse ; end

  # client error response class, status 400. The request could not be
  # understood by the server due to malformed syntax. The client SHOULD NOT
  # repeat the request without modifications.
  class BadRequestError < ClientErrorResponse ; end

  # client error response class, status 401. The request requires user
  # authentication. The client MAY repeat the request with a suitable
  # Authorization header field. If the request already included Authorization
  # credentials, then response indicates that authorization has been refused
  # for those credentials.
  class UnauthorizedError < ClientErrorResponse
    def initialize *args
      super
      @unauthorized = true
    end
  end

  # client error response class, status 403. The server understood the
  # request, but is refusing to fulfill it. Authorization will not help and
  # the request should not be repeated.
  class ForbiddenError < ClientErrorResponse ; end

  # client error response class, status 404. The server has not found anything
  # matching the Request-URI.
  class NotFoundError < ClientErrorResponse ; end

  # client error response class, status 405. The method specified in the
  # Request-Line is not allowed for the resource identified by the
  # Request-URI.
  class MethodNotAllowedError < ClientErrorResponse ; end

  # client error response class, status 408. The client did not produce a
  # request within the time that the server was prepared to wait.
  class RequestTimeoutError < ClientErrorResponse ; end

  # client error response class, status 409. The request could not be
  # completed due to a conflict with the current state of the resource.
  class ConflictError < ClientErrorResponse ; end

  # client error response class, status 411
  class LengthRequiredError < ClientErrorResponse #:nodoc:
  end

  # client error response class, status 412. The precondition given in one or
  # more of the request-header fields evaluated to false when it was tested on
  # the server.
  class PreconditionFailedError < ClientErrorResponse ; end

  # client error response class, status 413. The server is refusing to process
  # a request because the request entity is larger than the server is willing
  # or able to process, example a put request with size greater than allowed.
  class RequestEntityTooLargeError < ClientErrorResponse ; end

  # client error response class, status 414. The server is refusing to service
  # the request because the Request-URI is longer than the server is willing
  # to interpret.
  class RequestUriTooLargeError < ClientErrorResponse ; end

  # client error response class, status 415. The server is refusing to service
  # the request because the entity of the request is in a format not supported
  # by the requested resource for the requested method.
  class UnsupportedMediaTypeError < ClientErrorResponse ; end

  # client error response class, status 416
  class RequestRangeNotSatisfiableError < ClientErrorResponse #:nodoc:
  end

  # client error response class, status 422. The server understands the
  # content type of the request entity (hence a 415 Unsupported Media Type
  # status code is inappropriate), and the syntax of the request entity is
  # correct (thus a 400 (Bad Request) status code is inappropriate) but was
  # unable to process the contained instructions. For example, this error
  # condition may occur if an XML request body contains well-formed (i.e.,
  # syntactically correct), but semantically erroneous XML instructions.
  class UnprocessableEntityError < ClientErrorResponse ; end

  # client error response class, status 423
  class LockedError < ClientErrorResponse #:nodoc:
  end

  # server error response class, status 500. The server encountered an
  # unexpected condition which prevented it from fulfilling the request.
  class InternalServerError < ServerErrorResponse ; end

  # server error response class, status 503. The server is currently unable to
  # handle the request due to temporary overloading or maintenance of the
  # server. It is a temprory condition which will be alleviated after some
  # delay.
  class ServiceUnavailableError < ServerErrorResponse ; end

  # server error response class, status 501. The server does not support the
  # functionality required to fulfill the request.
  class NotImplementedError < ServerErrorResponse ; end

  # server error response class, status 505. The server does not support, or
  # refuses to support, the HTTP protocol version that was used in the request
  # message.
  class HttpVersionNotSupportedError < ServerErrorResponse ; end

  # server error response class, status 507. The method could not be performed
  # on the resource because the server is unable to store the representation
  # needed to successfully complete the request.
  class InsufficientStorageError < ServerErrorResponse
    attr_reader :dav_error

    def self.create(url, status, headers, body, method)
      dav_error = parse_dav_error headers, body
      self.new(url, status, headers, body, dav_error)
    end

    def initialize(url, status, headers, body, dav_error=nil)
      @body = body
      @dav_error = dav_error
      super(url, status, headers)
    end
  end

  # redirect response class, status 301
  class MovedPermanentlyResponse < RedirectionResponse #:nodoc:
  end

  # redirect response class, status 302
  class FoundResponse < RedirectionResponse #:nodoc:
  end

  # redirect response class, status 304
  class NotModifiedResponse < RedirectionResponse #:nodoc
  end

  # For multistatus responses that return individual DAV:response elements with
  # DAV:propstat elements
  class PropstatResponse < MultiStatusResponse
    
    attr_reader :resources

    # if there is only one url, then you can just pass a prop_key,
    #  and you will get a PropertyResult
    # otherwise, you must pass in a url, and you will get a hash
    #  of PropKey -> PropertyResult
    def [] url_or_prop_key
      if url_or_prop_key.is_a?(PropKey) || url_or_prop_key.is_a?(Symbol)
        if resources.size == 1
          return resources.values[0][url_or_prop_key]
        else
          raise("must pass url because there is " +
                "more than one url in the response")
        end
      else
        possible_keys =
          [ url_or_prop_key, url_or_prop_key.chomp('/'),
            "#{url_or_prop_key}/" ]
        possible_keys.each do |k|
          return resources[k] if resources.include? k
        end

        return nil
      end
    end

    def error?
      @error ||= @resources.values.any? do |properties|
        properties.values.any? { |r| r.status !~ /^2\d\d$/ }
      end
    end

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

    class << self

      def create(url, status, headers, body, method)
        resources = parse_body body, url
        return self.new(url, status, headers, body, resources)
      end

      private
      
      # returns a hash of PropKey -> PropertyResult
      def parse_propstats parent_elem
        properties = Hash.new do |h, k|
          pk = PropKey.strictly_prop_key k
          next h.include?(pk) ? h[pk] : nil
        end

        each_element_named parent_elem, 'propstat' do |ps_elem|
          ps_children = dav_elements_hash ps_elem, 'status', 'error', 'prop'
          raise BadResponseError unless ps_children.include? 'status'
          status = parse_status ps_children['status'].content

          dav_error = DavError.parse ps_children['error']
          ps_children['prop'].element_children.each do |property|
            pk = PropKey.get(namespace_href(property), property.name)
            result = PropertyResult.new pk, status, property, dav_error
            properties[pk] = result
          end
        end

        return properties
      end

      # returns hash of hashes: url -> PropKey -> PropertyResult
      def parse_body body, url
        root = parse_xml body
        assert_elem_name root, 'multistatus'

        return elements_named(root, 'response').inject({}) do |h, r|
          href_elem = first_element_named r, 'href'
          raise BadResponseError if href_elem.nil?
          href = href_elem.content
          h[href] = parse_propstats r
          next h
        end
      rescue ArgumentError
        raise BadResponseError
      end

    end
    

  end

  class MkcolResponse < PropstatResponse

    class << self

      private

      def parse_body body, url
        root = parse_xml body
        assert_elem_name root, 'mkcol-response'
        return { url => parse_propstats(root) }
      rescue ArgumentError
        raise BadResponseError
      end
    end
  end

  class ResponseFactory
    @@map = Hash.new { |h, k| h[k] = {} }

    # create the mapping for status,methodname to Response Class
    {
      ['200', :lock] => OkLockResponse,
      ['200', nil] => OkResponse,
      ['201', :lock] => OkLockResponse,
      ['201', :mkcol_ext] => MkcolResponse,
      ['201', nil] => CreatedResponse,
      ['204', nil] => NoContentResponse,
      ['207', :copy] => MultiStatusResponse,
      ['207', :lock] => MultiStatusResponse,
      ['207', :propfind] => PropstatResponse,
      ['207', :proppatch] => PropstatResponse,
      ['207', :search] => PropstatResponse,
      ['207', :report_version_tree] => PropstatResponse,
      ['207', :report_expand_property] => PropstatResponse,
      ['207', nil] => MultiStatusResponse,
      ['301', nil] => MovedPermanentlyResponse,
      ['302', nil] => FoundResponse,
      ['304', nil] => NotModifiedResponse,
      ['400', nil] => BadRequestError,
      ['401', nil] => UnauthorizedError,
      ['403', nil] => ForbiddenError,
      ['404', nil] => NotFoundError,
      ['405', nil] => MethodNotAllowedError,
      ['408', nil] => RequestTimeoutError,
      ['409', nil] => ConflictError,
      ['412', nil] => PreconditionFailedError,
      ['413', nil] => RequestEntityTooLargeError,
      ['414', nil] => RequestUriTooLargeError,
      ['415', nil] => UnsupportedMediaTypeError,
      ['422', nil] => UnprocessableEntityError,
      ['423', nil] => LockedError,
      ['424', :mkcol_ext] => MkcolResponse,
      ['424', nil] => ErrorResponse,
      ['500', nil] => InternalServerError,
      ['503', nil] => ServiceUnavailableError,
      ['501', nil] => NotImplementedError,
      ['505', nil] => HttpVersionNotSupportedError,
      ['507', nil] => InsufficientStorageError
    }.each do |(status, method), classname|
      if method then
        @@map[status][method] = classname
      else
        @@map[status].default = classname
      end
    end

    class << self
    
      def get(url, status, headers, body, method)
        map[status][method].create(url, status, headers, body, method)
      end

      def map() @@map; end
      
    end
    
  end
end
