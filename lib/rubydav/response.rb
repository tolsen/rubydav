require File.dirname(__FILE__) + '/acl'
require File.dirname(__FILE__) + '/lock'
require File.dirname(__FILE__) + '/rexml_fixes'
require File.dirname(__FILE__) + '/errors'
require File.dirname(__FILE__) + '/utility'
require File.dirname(__FILE__) + '/dav_error'

module RubyDav

  # Response classes returned when RubyDav.method is called
  # base Response class
  class Response

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
    
  end


  # successful response class, 2xx series
  class SuccessfulResponse < Response
    def error?
      false
    end

    def etag
    end
  end

  # redirect response class, 3xx series
  class RedirectionResponse < Response
  end

  # error response class, 4xx and 5xx series
  class ErrorResponse < Response
    def error?
      true
    end
  end

  # multistatus response class, status 207. It provides status for multiple
  # independent operations.
  class MultiStatusResponse < Response
    
    attr_reader :description
    attr_reader :body
    
    def error?
      @method == :copy
    end

    def self.create(url,status,headers,body,method)
      responses = Array.new
      root = REXML::Document.new(body).root

      raise BadResponseError unless (root.namespace == "DAV:" and root.name == "multistatus")

      description = REXML::XPath.first(root, "D:responsedescription/text()", {"D" => "DAV:"}).to_s
      response_elements = REXML::XPath.match(root, "D:response", {"D" => "DAV:"})
      raise BadResponseError if response_elements.empty?

      response_elements.each do |response_element|
        status_element = REXML::XPath.first(response_element, "D:status", {"D" => "DAV:"})
        sub_status = RubyDav.parse_status(status_element.text)
        
        hrefs = REXML::XPath.match(response_element, "D:href/text()", {"D" => "DAV:"})
        responses += hrefs.map do |href|
          ResponseFactory.get(href.to_s, sub_status, headers, nil, method)
        end
      end
      MultiStatusResponse.new(url, status, headers, body, responses, method, description)
    end

    # returns list of responses inside MultiStatusResponse
    attr_reader :responses

    private
    def initialize(url, status, headers, body, responses, method=nil, description=nil)
      @responses = responses || Array.new
      @responses << self
      @body = body
      @method = method
      @description = description
      super(url, status, headers)
      @unauthorized = responses.any? { |r| r.unauthorized? } unless responses.nil?
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
    #
    # lockinfo contains locktype, lockscope, depth, owner, timeout and
    # locktoken
    attr_reader :lockinfo

    def self.parse_timeout(timeout)
      timeout = timeout.text
      timeout.split('-')[1] if timeout =~ /Second-/
      INFINITY if timeout =~ /Infinite/
    end

    def self.parse_locktoken(locktoken)
      lthref = REXML::XPath.first(locktoken, "D:href", {"D" => "DAV:"})
      lthref.text
    end

    def self.parse_body(body)
      root = REXML::Document.new(body).root
      raise BadResponseError unless (root.namespace == "DAV:" && root.name == "prop")
      lockdiscovery = REXML::XPath.first(root, "D:lockdiscovery", {"D" => "DAV:"})
      activelock = REXML::XPath.first(lockdiscovery, "D:activelock", {"D" => "DAV:"})

      locktype = REXML::XPath.first(activelock, "D:locktype", {"D" => "DAV:"})
      lockscope = REXML::XPath.first(activelock, "D:lockscope", {"D" => "DAV:"})
      depth = REXML::XPath.first(activelock, "D:depth", {"D" => "DAV:"})
      owner = REXML::XPath.first(activelock, "D:owner", {"D" => "DAV:"})
      timeout = REXML::XPath.first(activelock, "D:timeout", {"D" => "DAV:"})
      locktoken = REXML::XPath.first(activelock, "D:locktoken", {"D" => "DAV:"})

      RubyDav::LockInfo.new(:type => :"#{locktype.elements.to_s}",
                            :scope => :"#{locktype.elements.to_s}",
                            :depth => depth.text,
                            :owner => owner.text,
                            :timeout => parse_timeout(timeout),
                            :token => parse_locktoken(locktoken)
                            )
    end

    def self.create(url, status, headers, body, method)
      lockinfo = parse_body(body)
      lockinfo.root = url
      self.new(url, status, headers, body, lockinfo)
    end

    private
    def initialize(url, status, headers, body, lockinfo)
      @lockinfo = lockinfo
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

  # client error response class, 4xx series
  class ClientErrorResponse < ErrorResponse
    include DavErrorHandler
    attr_reader :dav_error

    def self.create(url, status, headers, body, method)
        root = REXML::Document.new(body).root
        dav_error = DavErrorHandler.parse_dav_error(root)
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
    include DavErrorHandler
    attr_reader :dav_error

    def self.create(url, status, headers, body, method)
        root = REXML::Document.new(body).root
        dav_error = DavErrorHandler.parse_dav_error(root)
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
    def location
    end
  end

  # redirect response class, status 302
  class FoundResponse < RedirectionResponse #:nodoc:
    def location
    end
  end

  # redirect response class, status 304
  class NotModifiedResponse < RedirectionResponse #:nodoc
    # resource's entity-tag
    def etag
    end
  end


  # For mulistatus responses that return individual DAV:response elements with
  # DAV:propstat elements
  class PropstatResponse < MultiStatusResponse
    include DavErrorHandler
    attr_reader :propertyhash
    attr_reader :propertystatushash
    attr_reader :propertyerrorhash
    attr_reader :propertyfullhash

    # for a propfind, returns value if propkey was successfully found,
    # otherwise returns nil (check statuses)
    #
    # for a proppatch, returns true if propkey successfully patched, otherwise
    # nil.
    def [](propkey)
      @propertyhash[PropKey.strictly_prop_key(propkey)]
    end

    def include?(propkey)
      @propertyhash.include? PropKey.strictly_prop_key(propkey)
    end
        
    # returns status associated with propkey
    def statuses(propkey)
      @propertystatushash[PropKey.strictly_prop_key(propkey)]
    end

    # returns dav_error associated with propkey
    def dav_errors(propkey)
      @propertyerrorhash[PropKey.strictly_prop_key(propkey)]
    end

    def error?
      @error
    end


    def initialize(url, status, headers, body, propertyhash={},
                   propertystatushash={}, propertyerrorhash={},
                   propertyfullhash={}, error=false)
      @propertyhash = propertyhash
      @propertystatushash = propertystatushash
      @propertyerrorhash = propertyerrorhash
      @propertyfullhash = propertyfullhash
      @error = error
      super(url, status, headers, body, nil)
      @unauthorized = @propertystatushash.values.include? '401'
    end

    private
    def self.parse_propstats response
      propstats = REXML::XPath.match(response, "D:propstat", {"D" => "DAV:"})
      propstats.each do |propstat|
        status_elem = REXML::XPath.first(propstat, "D:status", {"D" => "DAV:"})
        status = RubyDav.parse_status(status_elem.text)
        dav_error_elem = REXML::XPath.first(propstat, "D:error", {"D" => "DAV:"})
        dav_error = DavErrorHandler.parse_dav_error(dav_error_elem)
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
        urlhash[href] ||= []
        self.parse_propstats(response) do |status, dav_error, props|
          urlhash[href] << [status, dav_error, props]
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

  class MkcolResponse < PropstatResponse

    def self.create(url,status,headers,body,method)
      root = REXML::Document.new(body).root
      raise BadResponseError unless (root.namespace == "DAV:" && root.name == "mkcol-response")
      response = REXML::XPath.match(root, "D:mkcol-response", {"D" => "DAV:"})

      propertyhash = {}
      propertystatushash = {}
      propertyerrorhash = {}
      propertyfullhash = {}
      success = false

      self.parse_propstats(root) do |sub_status, dav_error, props|

        success = (sub_status == "200")
        props.each_key do |prop|
          propertystatushash[prop] = sub_status
          propertyerrorhash[prop] = dav_error
          propertyfullhash[prop] = propertyhash[prop] = true if success
        end
      end
      MkcolResponse.new(url, status, headers, body, propertyhash, propertystatushash, propertyerrorhash, propertyfullhash, !success)
    end
  end

  # prop multistatus response class, status 207
  # response to a Propfind or a Proppatch
  class PropMultiResponse < PropstatResponse

    # returns parent PropMultiResponse
    attr_reader :parent

    # returns child PropMultiResponses.  Only defined for depth-1 or
    # depth-infinity propfinds
    attr_reader :children

    def responses
      @children.map { |bn, r| r.responses }.flatten << self
    end

    def unauthorized?
      @unauthorized || @children.values.any? { |r| r.unauthorized? }
    end

    def self.create(url,status,headers,body,method)
      urlhash = self.parse_body(body)
      responsehash = {}
      urlhash.each do |url, propstats|
        propertyhash = {}
        propertystatushash = {}
        propertyerrorhash = {}
        propertyfullhash = {}
        success = false
        propstats.each do |(sub_status, dav_error, properties)|
          success = (sub_status == "200")
          
          properties.each_pair do |k, v|
            propertyhash[k] = v.inner_xml if success
            propertyfullhash[k] = v.to_s_with_ns
          end if method == :propfind
          
          properties.each_key do |prop|
            propertystatushash[prop] = sub_status
            propertyerrorhash[prop] = dav_error
            propertyfullhash[prop] = propertyhash[prop] = true if (success && method == :proppatch)
          end
        end
        responsehash[RubyDav.uri_path(url)] = PropMultiResponse.new(url, '207', headers, body, propertyhash, propertystatushash, propertyerrorhash, propertyfullhash, !success)
      end
      createtree responsehash
    end

    def parent=(parentresponse)
      @parent = parentresponse
      parentresponse.children[File.basename(self.url)] = self
    end

    def initialize(url, status, headers, body, propertyhash={},
                   propertystatushash={}, propertyerrorhash={},
                   propertyfullhash={}, error=false)
      @children = Hash.new
      super url, status, headers, body, propertyhash, propertystatushash, propertyerrorhash, propertyfullhash, error
    end

    private
    def self.createtree(urlresponsehash)
      urlwithnoparent=nil
      
      urlresponsehash.each do |url,response|
        parentresponse = urlresponsehash[File.dirname(url)]
        
        if (!parentresponse || parentresponse == response)
          urlwithnoparent = url 
        else
          response.parent= parentresponse 
        end
      end
      urlresponsehash[urlwithnoparent] if urlwithnoparent
    end
  end

  # version-tree report response class, status 207
  class VersionMultiResponse < PropstatResponse
    attr_reader :versions

    def self.create(url,status,headers,body,method)
      urlhash = self.parse_body(body)
      responsehash = {}
      urlhash.each do |url, propstats|
        propertyhash = {}
        propertystatushash = {}
        propertyerrorhash = {}
        propertyfullhash = {}
        success = false
        propstats.each do |(sub_status, dav_error, properties)|
          success = (sub_status == "200")
          properties.each_pair do |k, v|
            propertyhash[k] = v.inner_xml
            propertyfullhash[k] = v.to_s_with_ns
          end
          properties.each_key do |prop|
            propertystatushash[prop] = sub_status
            propertyerrorhash[prop] = dav_error
          end
        end
        responsehash[RubyDav.uri_path(url)] = PropstatResponse.new(url, '207', headers, body, propertyhash, propertystatushash, propertyerrorhash, propertyfullhash, !success)
      end
      self.new(url, status, headers, responsehash, method)
    end

    private
    def initialize(url, status, headers, responsehash, method)
      @versions = responsehash
      super url, status, headers, body
    end

  end
  
  # response to an unsuccessful lock request (RubyDav.lock)
  class LockMultiResponse < MultiStatusResponse #:nodoc:
    # returns list of failed dependencies for the Lock request
    def failed_dependencies
    end

    # Response object pertaining to the request URL that you failed to lock
    def head
    end
  end


  # response for RubyDav.propfind_acl
  class PropfindAclResponse < PropMultiResponse

    # aces inherited from other resources
    # includes aces which are both inherited and protected
    attr_reader :inherited_acl

    # immutable (non-inherited) aces on the resource
    attr_reader :protected_acl

    # non-inherited and unprotected aces
    attr_reader :acl

    attr_reader :acl_status
    attr_reader :dav_error

    def self.create(url,status,headers,body,method)
      urlhash = self.parse_body(body)
      responsehash = {}
      urlhash.each do |url,propstats|
        inherited_acl,protected_acl,acl = *propstats[0][2][PropKey.get("DAV:", "acl")]
        dav_error = *propstats[0][1]
        acl_status = *propstats[0][0]
        responsehash[RubyDav.uri_path(url)] = PropfindAclResponse.new(url, '207', headers, body, inherited_acl, 
                                                                      protected_acl, acl, acl_status, dav_error)
      end
      createtree(responsehash)
    end
    
    def initialize(url, status, headers, body, inherited_acl, protected_acl, acl,acl_status, dav_error)
      @inherited_acl = inherited_acl
      @protected_acl = protected_acl
      @acl = acl
      @acl_status = acl_status
      @dav_error = dav_error

      acl_key = PropKey.get("DAV:", "acl")
      
      propertystatushash = { acl_key => acl_status}
      propertyerrorhash = { acl_key => dav_error}
      propertyhash = { acl_key => [inherited_acl, protected_acl,acl]}
      super(url, status, headers, body, propertyhash, propertystatushash, propertyerrorhash)
    end

    private
    def self.parse_prop(prop_element)
      inherited_acl = Acl.new
      protected_acl = Acl.new
      acl = Acl.new

      ace_elements = REXML::XPath.match(prop_element, "D:acl/D:ace", {"D" => "DAV:"})
      
      ace_elements.each do |ace_element|
        privileges = []
        inheritedurl = ""
        
        principal_element = REXML::XPath.first(ace_element, "D:principal", {"D" => "DAV:"})
        principal = parse_principal_element(principal_element)

        grantdeny_element = REXML::XPath.first(ace_element, "D:grant|D:deny", {"D" => "DAV:"})
        action = grantdeny_element.name.to_sym
        
        REXML::XPath.each(grantdeny_element, "D:privilege/*", {"D" => "DAV:"}) do |privilege|
          priv = PropKey.get(privilege.namespace, privilege.name)
          priv = privilege.name.to_sym if priv.dav?
          privileges << priv
        end
        
        protected = !REXML::XPath.first(ace_element, "D:protected", {"D" => "DAV:"}).nil?

        inheritedurl = REXML::XPath.first(ace_element, "D:inherited/D:href/text()", {"D" => "DAV:"})
        inherited = !inheritedurl.nil?


        if inherited
          inherited_acl << InheritedAce.new(inheritedurl.to_s, action, principal, protected, *privileges)
        elsif protected
          protected_acl << Ace.new(action, principal, protected, *privileges)
        else
          acl << Ace.new(action, principal, protected, *privileges)
        end
      end
      return {PropKey.get("DAV:", "acl") => [inherited_acl, protected_acl, acl]}
    end
    
    def self.parse_principal_element(principal_element)
      href = REXML::XPath.first(principal_element, "D:href/text()", {"D" => "DAV:"})
      href = href.to_s if href
      property = REXML::XPath.first(principal_element, "D:property/*", {"D" => "DAV:"})
      property = property && PropKey.get(property.namespace, property.name)
      principal = href || property || principal_element.elements[1].name.to_sym
    end
  end

  # response for RubyDav.propfind_cups
  class PropfindCupsResponse < PropMultiResponse
    # list of privileges that the current user has on the resource
    attr_reader :privileges
    
    attr_reader :cups_status
    attr_reader :dav_error

    def self.create(url, status, headers, body, method)
      urlhash = self.parse_body(body)
      responsehash = {}
      urlhash.each do |url, propstats|
        privileges = propstats[0][2][PropKey.get("DAV:", "current-user-privilege-set")]
        dav_error = propstats[0][1]
        cups_status = propstats[0][0]
        responsehash[RubyDav.uri_path(url)] = PropfindCupsResponse.new(url, '207', headers, body,
                                                                       privileges, cups_status, dav_error)
      end
      createtree(responsehash)
    end
    
    def initialize(url, status, headers, body, privileges, cups_status, dav_error)
      @privileges = privileges
      @cups_status = cups_status
      @dav_error = dav_error
      propertystatushash = {RubyDav::PropKey.get("DAV:", "current-user-privilege-set") => cups_status}
      propertyerrorhash = {RubyDav::PropKey.get("DAV:", "current-user-privilege-set") => dav_error}
      propertyhash = {RubyDav::PropKey.get("DAV:", "current-user-privilege-set") => privileges}
      super(url, status, headers, body, propertyhash, propertystatushash, propertyerrorhash)
    end

    private

    def self.parse_prop(prop_element)
      privileges = []
      REXML::XPath.each(prop_element, "D:current-user-privilege-set/D:privilege/*", {"D" => "DAV:"}) do |privilege|
        privileges << privilege.name
      end
      return {PropKey.get("DAV:", "current-user-privilege-set") => privileges}
    end
    
  end

  class SearchResponse < MultiStatusResponse
    attr_reader :responsehash

    def self.create(url, status, headers, body, method)
      urlhash = PropMultiResponse.parse_body(body)
      responsehash = {}
      urlhash.each do |url, propstats|
        propertyhash = {}
        propertystatushash = {}
        propertyerrorhash = {}
        propertyfullhash = {}
        success = false
        propstats.each do |(sub_status, dav_error, properties)|
          success = (sub_status == "200")
          properties.each_pair do |k, v|
            propertyhash[k] = v.inner_xml
            propertyfullhash[k] = v.to_s_with_ns
          end
          properties.each_key do |prop|
            propertystatushash[prop] = sub_status
            propertyerrorhash[prop] = dav_error
          end
        end
        responsehash[RubyDav.uri_path(url)] = PropMultiResponse.new(url, '207', headers, body, propertyhash, propertystatushash, propertyerrorhash, propertyfullhash, !success)
      end
      SearchResponse.new(url, status, headers, body, responsehash, method)
    end

    def initialize(url, status, headers, body, urlresponsehash, method)
      @responsehash = urlresponsehash
      super(url, status, headers, body, @responsehash.values, method)
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
      ['207', :propfind] => PropMultiResponse,
      ['207', :proppatch] => PropMultiResponse,
      ['207', :search] => SearchResponse,
      ['207', :propfind_cups] => PropfindCupsResponse,
      ['207', :propfind_acl] => PropfindAclResponse,
      ['207', :report_version_tree] => VersionMultiResponse,
      ['207', :report_expand_property] => PropMultiResponse,
      ['207', nil] => MultiStatusResponse,
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
    
    def self.get(url, status, headers, body, method)
      @@map[status][method].create(url, status, headers, body, method)
    end
  end
end
