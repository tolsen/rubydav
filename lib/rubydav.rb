#
# :main: lib/rubydav.rb
# = rubydav.rb
#
# Copyright (c) 2008, 2009 Lime Labs LLC
# Copyright (c) 2007, 2008 Lime Spot LLC
#
# See RubyDav for an overview and examples.
#

module RubyDav
end

unless defined? RubyDav::RUBYDAV_RB_INCLUDED
  RubyDav::RUBYDAV_RB_INCLUDED = true

  $:.unshift File.join(File.dirname(__FILE__), '../../better_httpauth/lib')

  require File.dirname(__FILE__) + '/rubydav/acl'
  require File.dirname(__FILE__) + '/rubydav/auth'
  require File.dirname(__FILE__) + '/rubydav/auth_world'
  require File.dirname(__FILE__) + '/rubydav/active_lock'
  require File.dirname(__FILE__) + '/rubydav/connection_pool'
  require File.dirname(__FILE__) + '/rubydav/current_user_privilege_set'
  require File.dirname(__FILE__) + '/rubydav/file_fixes'
  require File.dirname(__FILE__) + '/rubydav/http_fixes'
  require File.dirname(__FILE__) + '/rubydav/if_header'
  require File.dirname(__FILE__) + '/rubydav/lock_discovery'
  require File.dirname(__FILE__) + '/rubydav/property_result'
  require File.dirname(__FILE__) + '/rubydav/response'
  require File.dirname(__FILE__) + '/rubydav/rubydav_xml_builder'
  require File.dirname(__FILE__) + '/rubydav/supported_lock'
  require File.dirname(__FILE__) + '/rubydav/supported_privilege_set'
  require File.dirname(__FILE__) + '/rubydav/webdav'

  require 'rubygems'
  require 'log4r'
  require 'shared-mime-info'

  # == What Is This Library?
  #
  # This library provides the functionality to access a WebDAV server.
  # For details on WebDAV, see the {WebDAV homepage}[http://www.webdav.org].
  #
  # RubyDav methods send requests to the server and return the appropriate
  # response object
  #
  # Most methods perform a WebDAV request.  These methods all take at
  # least one url and optionally an options hash.
  #
  # Options common to all WebDAV request methods are:
  # * <tt>:username</tt> => username to authenticate with
  # * <tt>:password</tt> => password to authenticate with
  # * <tt>:digest_a1</tt> => MD5sum(username:realm:password).  Can be used in place of password for digest auth
  # * <tt>:realm</tt> => authentication realm (optional)
  # * <tt>:force_basic_auth</tt> => <tt>true</tt> | <tt>false</tt> (defaults to <tt>false</tt>)
  #
  # RubyDAV avoids sending passwords in the clear.  It will choose
  # digest authentication when available, and will refuse to use basic
  # authentication over an unencrypted connection to a remote server.
  # To force basic authentication anyway, set <tt>:force_basic_auth</tt>
  # to <tt>true</tt>.
  #
  #--
  # * :if_match => etag - perform the command only if etag matches
  # *   :if_none_match => '*' - perform the command only if there is no previous
  #                             file
  # *   :if_none_match => etag - perform the command only if nothing matches etag
  # *   :if_none_match => [etag1, etag2] - perform the command only if nothing
  #                                        matches etags
  # *   :if_modified_since => date - perform the command only if modified after
  #                                  date
  # *   :if_unmodified_since => date - perform the command only if unmodified
  #                                    since date
  # *   :if => token
  # *   :if => [token1, token2]
  # *   :if => {url1 => token1, url2 => token2}
  #       where a token is a locktoken or an etag
  # *   :strict_if => false, it is by default true. If you provide a lock token
  #     and resource is not locked then the request fails. if :strict_if is
  #     false then in such a case the request will not fail.
  #++
  #
  # == Examples
  #
  # === Getting content
  #
  #   response = RubyDav.get('http://www.example.org/user/index.html')
  #   puts response.body unless response.error?
  #
  # On success, OkResponse with status 200 is returned else appropriate error
  # response is returned
  #
  # === Putting a file
  #
  #   response = RubyDav.put('http://www.example.org/user/index.html', stream,
  #                          :username => 'tim', :password => 'swordfish' })
  #   puts response.status unless response.error? # which should be 201 or 204
  #
  # If the request URI does not exist, a CreatedResponse with status 201 is
  # returned on success.
  #
  # If the request URI did exist previously, a NoContentResponse with status 204
  # is returned on success, else appropriate error response.
  #
  # === Deleting a file
  #
  #   response = RubyDav.delete('http://www.example.org/user/index.html',
  #                             :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # On success, a NoContentResponse with status 204 is returned.
  #
  # === Deleting a collection and all its descendents
  #
  #   response = RubyDav.delete('http://www.example.org/user/tempfiles',
  #                             :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error? # which will be 204 on success
  #
  # If the user has DAV:unbind privileges on all directories then a
  # NoContentResponse with status 204 is returned.
  #
  # If the user does not have DAV:unbind privilege on /tempfiles then a
  # ForbiddenError with status 403 is returned.
  #
  # If the user has DAV:unbind privileges on /tempfiles and /tempfiles/images
  # but does not have DAV:unbind privilege on /tempfiles/pages then a
  # MultiStatusResponse with status 207 is returned.
  #
  # To retrieve the list of responses:
  #
  #   responselist = response.responses
  #
  # MultiStatusResponse#responses gives a list of all the responses contained
  # inside the MultiStatusResponse.
  #
  # ForbiddenResponse with status 403 for url
  # 'http://www.example.org/user/tempfiles/pages' is returned
  #
  # Note: http://www.example.org/user/tempfiles/images is deleted but
  # http://www.example.org/user/tempfiles is not deleted since all its children
  # cannot be deleted.
  #
  # === Create a collection
  #
  #   response = RubyDav.mkcol('http://www.example.org/user/newcollection',
  #                            :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # If request URI did not exist previously then CreatedResponse with status 201
  # is returned on success.
  #
  # === Trying to create a collection and failing
  #
  # In this example, RubyDav will try to make a collection over an existing URI.
  # Assume a file was already present for the Request-URI.
  #
  #   response = RubyDav.mkcol('http://www.example.org/user/newcollection',
  #                            :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # MethodNotAllowedError with status 405 is returned since there already exists
  # a file for the Request-URI
  #
  # === Copying file with depth zero and overwrite true
  #
  #   response = RubyDav.copy('http://www.example.org/user/a.html',
  #                           'http://www.example.org/user/b.html',
  #                           0, true,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # If destination URI did not exist previously, CreatedResponse with status 201
  # is returned.
  #
  # If destination URI did exist previously, then destination URI is overwritten
  # and NoContentResponse with status 204 is returned.
  #
  # === Copying file with overwrite false
  #
  #   response = RubyDav.copy('http://www.example.org/user/a.html',
  #                           'http://www.example.org/user/b.html',
  #                           RubyDav::INFINITY, false,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # Since overwrite was false, if destination URI did exist previously then copy
  # fails and PreconditionFailedError with status 412 is returned.
  #
  # If destination URI did not exist then CreatedResponse with status 201 is
  # returned on success.
  #
  # === Copying a collection
  #
  # Assume /mysite contains two children /images and /pages.  The destination is
  # /myoldsite which currently contains /index.html and /background.gif.
  #
  #   response = RubyDav.copy('http://www.example.org/user/mysite',
  #                           'http://www.limespot/com/user/myoldsite',
  #                           RubyDav::INFINITY, true,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # NoContentResponse with status 204 is returned on success.  The old contents
  # of /myoldsite are deleted and now it contains /images and /pages.
  #
  # If the user does not have DAV:read privilege on /mysite then ForbiddenError
  # with status 403 is returned and /myoldsite/index.html and
  # /myoldsite/background.gif are not deleted.
  #
  # If the user does not have DAV:read privilege on /mysite/pages but has
  # DAV:read privilege on /mysite and /mysite/images then MultiStatusResponse
  # with status 207 is returned.
  #
  # Old contents, /myoldsite/index.html and /myoldsite/background.gif are
  # deleted and /myoldsite now contains only /images.
  #
  # === Moving file with overwrite true
  #
  # <tt>depth</tt> is always assumed infinity.
  #
  #   response = RubyDav.move('http://www.example.org/user/a.html',
  #                           'http://www.example.org/user/b.html',
  #                           true,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # If destination URI did not exist previously, CreatedResponse with status 201
  # is returned.
  #
  # If destination URI did exist previously, then destination URI is overwritten
  # and NoContentResponse with status 204 is returned.
  #
  # === Moving file with overwrite false
  #
  #   response = RubyDav.move('http://www.example.org/user/a.html',
  #                           'http://www.example.org/user/b.html',
  #                           false,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # Since overwrite was false, if destination URI did exist previously then move
  # fails and PreconditionFailedError with status 412 is returned.
  #
  # If destination URI did not exist then CreatedResponse with status 201 is
  # returned on success.
  #
  # === Moving a collection
  #
  # Assume /mysite contains two children /images and /pages.  The destination is
  # /myoldsite which currently contains /index.html and /background.gif
  #
  #   response = RubyDav.move('http://www.example.org/user/mysite',
  #                           'http://www.limespot/com/user/myoldsite',
  #                           true,
  #                           :username => 'tim', :password => 'swordfish'})
  #   puts response.status unless response.error?
  #
  # If successful NoContentResponse with status 204 is returned.  Since
  # overwrite was true, the old contents of /myoldsite are deleted and
  # /myoldsite now contains /images and /pages.  /mysite will also stop
  # existing.
  #
  # In case we did not have DAV:read privilege on /mysite then ForbiddenError
  # with status 403 is returned and /myoldsite/index.html and
  # /myoldsite/background.gif are not be deleted and /mysite and its contents
  # are not affected.
  #
  # In case we did not have DAV:read privilege on /mysite/pages but had DAV:read
  # privilege on /mysite and /mysite/images, still move succeeds and
  # NoContentResponse with status 204 is returned
  #
  # === Retrieving all properties (but not their values) defined on a file
  #
  #   response = RubyDav.propfind('http://www.example.org/user/index.html',
  #                               0,
  #                               :propname,
  #                               :username => 'tim', :password => 'swordfish'})
  #
  # On success, PropMultiResponse with status 207 is returned.  All defined
  # properties can be accessed from the response.
  #
  # === Retrieving all properties (but not their values) defined on a collection and its descendents
  # PropMultiResponse has a tree structure where a response contains its
  # immediate children.  We can traverse the tree to get to any descendent of
  # the Request-URI.
  #
  # assume /mycollection contains a collection /mysite and /mysite contains a
  # file index.html
  #
  #   response = RubyDav.propfind('http://www.example.org/user/mycollection',
  #                               RubyDav::INFINITY,
  #                               :propname,
  #                               :username => 'tim', :password => 'swordfish'})
  #
  # On success, PropMultiResponse with status 207 is returned.
  #
  # All defined properties can be accessed from the response.
  #
  # PropMultiResponse defined for /mysite is accessible in this way:
  #
  #   response2 = response.children['mysite']
  #
  # PropMultiResponse defined for /index.html is accessible in this way:
  #
  #   response3 = response.children['index.html']
  #
  # === Retrieving (almost) all properties and values defined on a file
  #
  # Note that an :allprop response does not necessarily contain live properties
  # defined outside {RFC 2518}[http://greenbytes.de/tech/webdav/rfc2518.html].
  #
  #   response = RubyDav.propfind('http://www.example.org/user/index.html',
  #                               0,
  #                               :allprop,
  #                               :username => 'tim', :password => 'swordfish'})
  #
  # On success, PropMultiResponse with status 207 is returned.
  #
  # All defined properties can be accessed on the response.
  #
  #   response[:displayname] # gives the file's displayname
  #
  # === Retrieving (almost) all properties and values defined on a collection and its descendents
  #
  # assume /mycollection contains a file index.html
  #
  #   response = RubyDav.propfind('http://www.example.org/user/mycollection',
  #                               RubyDav::INFINITY,
  #                               :allprop,
  #                               :username => 'tim', :password => 'swordfish'})
  #
  # On success, PropMultiResponse with status 207 is returned.
  #
  # All properties can be accessed on the response.
  #
  #   response2 = response.children['/index.html']
  #
  # PropMultiResponse#children contains PropMultiResponses for all the immediate
  # children of the resource.
  #
  # We access the PropMultiResponse for index.html's displayname from the
  # PropMultiResponse of its parent in this way:
  #
  #   response2[:displayname]
  #
  # Assuming index.html has a custom property tags with namespace
  # http://example.org/mynamespace, to retrieve the value of this property:
  #
  #   response2[Propkey.get('http://www.example.com/mynamespace', 'tags')]
  #
  # === Retrieving specified properties and values for a file
  #
  #   pk = Propkey.get('http://example.org/mynamespace', 'author')
  #   response = RubyDav.propfind('http://www.example.org/user/index.html',
  #                               0,
  #                               :displayname,
  #                               PropKey.get('http://example.org/namespace','author'),
  #                               :username => 'tim', :password => 'swordfish'})
  #
  # On success, PropMultiResponse with status 207 is returned.
  #
  # All specified properties can be accessed from the response.
  #
  # To retrieve the file's displayname:
  #
  #   response[:displayname]
  #
  # To retrieve the status associated with displayname property value retrieval:
  #
  #   response.statuses[:displayname]
  #
  # If the user has privilege to retrieve the property it will be 200 OK, else
  # appropriate error
  #
  #   response[Propkey.get('http://example.org/mynamespace', 'author')]
  #
  # If the user has read privilege on the property, it will give the author
  # property with namespace http://example.org/mynamespace value else nil
  #
  # === Retrieving directory listing for a Request-URI
  #
  # We send a depth 1 Propfind request to get the directory listing.
  # PropMultiResponse and its children form the directory listing.
  #
  #   response = RubyDav.propfind('http://www.example.org/user/',
  #                               1,
  #                               :getcontentlength, :getcontenttype, :getlastmodified,
  #                               :username => 'tim', :password => 'swordfish'})
  #   puts response.uri # display the request URI
  #   response.children.each do |bindname, childresponse|
  #      puts bindname # name of the child file
  #      puts childresponse[:getcontentlength] # contentlength of the child file
  #   end
  #
  # === Updating properties of a file
  #
  #   props = {
  #     :displayname => 'StartPage',
  #     Propkey.get('http://example.org/mynamespace', 'author') => :remove,
  #     Propkey.get('http://example.org/mynamespace', 'tags') => 'personal'
  #   }
  #   response = RubyDav.proppatch('http://www.example.or/user/index.html',
  #                                props,
  #                                :username => 'tim', :password => 'swordfish'})
  #
  # PropMultiResponse with status 207 is returned or appropriate error message
  # status corresponding to all set/remove properties can be accessed on it.
  #
  # These return true if successful else nil:
  #
  #   response[:displayname]
  #   response[:Propkey.get('http://example.org/mynamespace', 'tags')]
  #
  # === Setting access control properties of a collection
  #
  # acl command overwrites the access control list of a resource
  #
  # In this example, we first do a propfind_acl in order to retrieve the Acl.
  # Then we prepend a new Ace to the Acl and send it back using RubyDav.acl
  #
  #   response = RubyDav.propfind_acl('http://www.example.org/user',
  #                                    0,
  #                                    :username => 'tim',
  #                                    :password => 'swordfish'})
  #
  #   # if propfind_acl was successful
  #   unless response.error?
  #      acl = response.acl
  #      # prepend the new Ace
  #      acl.unshift Ace.new(:grant, 'http://www.example.org/user/mit', false, :all)
  #      response = RubyDav.acl('http://www.example.org/user', acl,
  #                             :username => 'tim',
  #                             :password => 'swordfish'})
  #      # set the access control properties of the resource
  #   end
  #
  # On success, OkResponse with status 200 is returned else appropriate error
  # response
  #

  module RubyDav
    # Constant Infinity
    INFINITY = 1.0 / 0.0 unless defined? INFINITY

    class Request

      # Retrieves the information identified by the Request-URI
      # (only for non-collection resources)
      #
      # Returns
      # * OkResponse with body for success
      # * else appropriate ErrorResponse.
      def get(url, options={})
        request :get, url, nil, options
      end

      def head(url, options={})
        request :head, url, nil, options
      end

      # HTTP POST request.
      #
      def post(url, body, options={})
        request :post, url, body, options
      end

      # Creates or modifies information identified by the Request-URI.
      #
      # Returns
      # * CreatedResponse if new file created
      # * NoContentResponse if existing file overwritten
      # * else appropriate ErrorResponse.
      #
      # overwrite is true by default.
      def put(url, stream, options={})
        request :put, url, stream, options
      end

      # Deletes the Request-URI. Depth is infinity by default.
      # For a collection deletes the collection and all its children.
      #
      # Returns
      # * NoContentResponse for success
      # * MultiStatusResponse in case of an error with a child of the Request-URI
      # * else appropriate ErrorResponse.
      def delete(url, options={})
        request :delete, url, nil, options
      end
      
      # Creates a collection identified by the Request-URI.
      #
      # Returns
      # * CreatedResponse if successful
      # * else appropriate ErrorResponse.
      def mkcol(url, options={})
        request :mkcol, url, nil, options
      end

#       def mkcol_ext(url, props, options={})
#         requestbody = String.new
#         xml ||= RubyDav::XmlBuilder.generate(requestbody)

#         xml.D(:mkcol, "xmlns:D" => "DAV:") do
#           xml.D(:set) do
#             xml.D(:prop) do
#               props.each do |propkey, value|
#                 propkey =  PropKey.strictly_prop_key(propkey)
#                 propkey.printXML xml, value
#               end
#             end
#           end
#         end

#         bodystream = StringIO.new requestbody
#         request :mkcol_ext, url, bodystream, options
#       end

      # Creates a duplicate of the Source-URI at the Destination-URI.
      # If depth is infinity, copies collection and all its descendents.
      # fails if overwrite is false and destination exists.
      #
      # Copy collection is not transactional, even if some descendents fail
      # the rest are copied
      #
      # Returns
      # * CreatedResponse if Destination-URI did not exist and created
      # * NoContentResponse if Destination-URI existed and overwritten.
      # * MultiStatusResponse in case of an error with a child of the Request-URI
      # * else appropriate ErrorResponse.
      def copy(srcurl, desturl, depth=INFINITY, overwrite=true, options={})
        options = options.merge( :destination => desturl,
                                 :depth => depth,
                                 :overwrite => overwrite )
        request :copy, srcurl, nil, options
      end

      # Remaps the Source-URI to the Destination-URI.
      # fails if overwrite is false and destination exists.
      #
      # Move collection is not transactional, even if some descendents fail
      # the rest are moved
      #
      # Returns
      # * CreatedResponse if Destination-URI did not exist and created
      # * NoContentResponse if Destination-URI existed and overwritten.
      # * MultiStatusResponse in case of an error with a child of the Request-URI
      # * else appropriate ErrorResponse.
      def move(srcurl, desturl, overwrite=true, options={})
        options = options.merge( :destination => desturl,
                                 :overwrite => overwrite )
        request :move, srcurl, nil, options
      end

      # options: scope, owner, type, depth, timeout, refresh
      #
      # when refreshing, set :refresh to true and set the :if option.
      # you may ask for a new timeout but you may not change scope,
      # owner, type, or depth.
      def lock url, options={}
        stream = nil
        unless options[:refresh]
          scope = options[:scope] || :exclusive
          type = options[:type] || :write

          stream = RubyDav.build_xml_stream do |xml|
            xml.lockinfo 'xmlns' => 'DAV:' do
              xml.locktype { xml.tag! type }
              xml.lockscope { xml.tag! scope }
              xml.owner { xml << options[:owner] } if options.include? :owner
            end
          end
        end
        
        request :lock, url, stream, options
      end

      def unlock(url, lock_token, options={})
        options = options.merge( :lock_token => lock_token )
        request :unlock, url, nil, options
      end

      def bind(url, seg, href, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:bind, "xmlns:D" => "DAV:") do
            xml.D(:segment, seg)
            xml.D(:href, fullurl(href))
          end
        end

        request :bind, url, stream, options
      end

      def unbind(coll, seg, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:unbind, "xmlns:D" => "DAV:") do
            xml.D(:segment, seg)
          end
        end

        request :unbind, coll, stream, options
      end

      def rebind(coll, seg, href, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:rebind, "xmlns:D" => "DAV:") do
            xml.D(:segment, seg)
            xml.D(:href, fullurl(href))
          end
        end
        
        request :rebind, coll, stream, options
      end

      # Query all the given properties and their values on the Request-URI and its
      # descendents depending on the depth parameter.
      #
      # props is either :allprop, :propname, or a list of propkeys/symbols eg.
      # :displayname, Propkey.get('http://example.org/mynamespace', 'author')
      #
      # * propfind with :allprop, returns PropstatResponse with all the
      #   properties and their values defined on the Request-URI
      # * propfind with :propname, returns PropstatResponse with all the defined
      #   properties on the Request-URI
      # * propfind with an array returns PropstatResponse with the request
      #   properties and their values for the Request-URI.
      #
      # For the corresponding value of depth all the descendents and their
      # respective properties and values are also reported. The response for the
      # children of a URI are available by PropstatResponse.children
      #
      # options hash can be passed as the last element of props.
      def propfind(url, depth=INFINITY, *props)
        options = props.last.is_a?(Hash) ? props.pop.dup : {}
        options[:depth] = depth

        bodystream = generate_propfind_bodystream(*props)
        request :propfind, url, bodystream, options
      end

      # Proppatch modifies the properties of the Request-URI.
      #
      # If a property value is :remove, the property is removed. If the property
      # value is nil, no operation is performed.  In all other cases, the
      # corresponding value is set.
      #
      # Proppatch is transactional, either all property updates succeed or all
      # fail.
      #
      # props contains a mapping of propkeys/symbols to values
      #
      # eg:
      #   {
      #     :displayname => 'foo',
      #     Propkey.get('http://example.org/mynamespace', 'author') => 'myname',
      #     Propkey.get('http://example.org/mynamespace', 'author2') => nil
      #   }
      #
      # Returns
      # * PropstatResponse with statuses containing
      #   * 200 OK, Note if one command succeeded then all succeed
      #   * Error Codes.
      # * appropriate error response
      def proppatch(url, props, options={})
        setprops = props.reject{|propkey, value| (:remove == value)|| (nil == value) }
        removeprops = props.reject{|propkey, value| :remove != value}

        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:propertyupdate, "xmlns:D" => "DAV:") do
            [[:set,setprops], [:remove, removeprops]].each do |(method, updates)|
              if (updates.size > 0)
                xml.D(method) do
                  xml.D(:prop) do
                    updates.each do |propkey, value|
                      propkey =  PropKey.strictly_prop_key(propkey)
                      propkey.printXML xml, value
                    end
                  end
                end
              end
            end
          end
        end

        request :proppatch, url, stream, options
      end

      # Sets the access control entries of the resource.  Overwrites all
      # non-inherited and unprotected Aces.
      #
      # Acl object contains all the Aces to be set.
      #
      # To set the Acl, user should first do a propfind_acl.  Prepend the Ace to
      # be set to PropfindAclResponse#acl and send it as the acl parameter.
      #
      # Returns
      # * OkResponse on success
      # * else appropriate error response
      def acl(url, acl, options={})
        acl.delete_if{|ace| ace.protected? || ace.kind_of?(InheritedAce)}
        acl.compact! if acl.compacting?
        stream = RubyDav.build_xml_stream { |xml| acl.printXML xml }
        request :acl, url, stream, options
      end

      # Start versioning on the given url
      #
      # Returns
      # * OkResponse on success
      # * else appropriate error response
      def version_control(url, options={})
        request :versioncontrol, url, nil, options
      end
      
      # Applied to a checked-in url, to start modifying it and its dead properties
      #
      # Returns
      # * OkResponse on success
      # * else appropriate error response
      def checkout(url, forkok, options={})
        stream = nil
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:checkout, "xmlns:D" => "DAV:") do
            xml.D(:"fork-ok")
          end
        end if forkok
        request :checkout, url, stream, options
      end
      
      # Applied to a checked out url to produce a new version whose content and dead properties
      # are copied from the checked out resource.
      # If keepcheckedout is true then file will be checkedout after creating a new version.
      #
      # Returns
      # * CreatedResponse on success
      # * else appropriate error response
      def checkin(url, keepcheckedout, forkok, options={})
        stream = nil
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:checkin, "xmlns:D" => "DAV:") do
            if forkok
              xml.D(:"fork-ok")
            end
            if keepcheckedout
              xml.D(:"keep-checked-out")
            end
          end
        end if forkok || keepcheckedout
        
        request :checkin, url, stream, options
      end
      
      # Applied to a checked out url to cancel any changes made and restore the pre-checked in state
      #
      # Returns
      # * OkResponse on success
      # * else appropriate error response
      def uncheckout(url, options={})
        request :uncheckout, url, nil, options
      end

      def version_tree_report(url, *props)
        options = {}
        options.merge!(props.pop) if props.last.is_a? Hash

        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:"version-tree", "xmlns:D" => "DAV:") do
            xml.D(:prop) do
              props.each do |prop|
                propkey = PropKey.strictly_prop_key(prop)
                propkey.printXML(xml)
              end
            end
          end
        end

        request :report_version_tree, url, stream, options
      end

      def report(url, stream)
        request :report, url, stream, {}
      end

      def expand_property_report(url, eprops, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:"expand-property", "xmlns:D" => "DAV:") do
            generate_expand_property_report(xml, eprops)
          end
        end

        request :report_expand_property, url, stream, options
      end

      def search(url, scope, wherexml, *props)
        options = props.last.is_a?(Hash) ? props.pop.dup : {}
        
        nresults, orderlist, offset, bitmarks =
          options.values_at :limit, :orderby, :offset, :bitmarks

        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:searchrequest, "xmlns:D" => "DAV:") do
            xml.D(:basicsearch) do
              xml.D(:select) do
                if(:allprop == props[0])
                  xml.D(props[0])
                else
                  xml.D(:prop) do
                    props.each do |prop|
                      propkey = PropKey.strictly_prop_key(prop)
                      propkey.printXML xml
                    end
                  end
                  if !bitmarks.nil?
                    xml.LB(:bitmark, 
                           "xmlns:LB" => "http://limebits.com/ns/1.0/") do
                        bitmarks.each do |bitmark|
                            xml.BM(bitmark.to_sym, "xmlns:BM" => "http://limebits.com/ns/bitmarks/1.0/")
                        end
                    end
                  end
                end
              end
              xml.D(:from) do
                scope.each do |href, depth|
                  xml.D(:scope) do
                    xml.D(:href, href)
                    xml.D(:depth, depth.to_s)
                  end
                end
              end
              xml.D(:where) { xml << wherexml }
              if nresults
                xml.D(:limit) { xml.D(:nresults, nresults.to_s) }
              end
              if orderlist
                xml.D(:orderby) do
                  orderlist.each do |(prop, order)|
                    xml.D(:order) do 
                      xml.D(:prop) do 
                        propkey = PropKey.strictly_prop_key(prop)
                        propkey.printXML xml
                      end
                      xml.D(order)
                    end
                  end
                end
              end

              if offset
                xml.limebits(:offset, offset.to_s, "xmlns:limebits" => "http://limebits.com/ns/1.0/") 
              end
            end
          end
        end
        
        request :search, url, stream, options
      end

      def mkredirectref(url, reftarget, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:mkredirectref, "xmlns:D" => "DAV:") do
            xml.D(:reftarget) do
              xml.D(:href, reftarget)
            end
            xml.D(:"redirect-lifetime") { xml.D(options[:lifetime]) } if options[:lifetime]
          end
        end

        request :mkredirectref, url, stream, options
      end

      def updateredirectref(url, options={})
        stream = RubyDav.build_xml_stream do |xml|
          xml.D(:updateredirectref, "xmlns:D" => "DAV:") do
            xml.D(:reftarget) { xml.D(:href, options[:reftarget]) } if options[:reftarget]
            xml.D(:"redirect-lifetime") { xml.D(options[:lifetime]) } if options[:lifetime]
          end
        end
        
        request :updateredirectref, url, stream, options
      end

      def self.clone_class_from_instance_methods *method_syms
        anon_module = Module.new do
          method_syms.each do |method|
            define_method method do |*args|
              self.new.send method, *args
            end
          end
        end
        self.extend anon_module
      end

      clone_class_from_instance_methods(
                                        :acl,
                                        :bind,
                                        :checkin,
                                        :checkout,
                                        :copy,
                                        :delete,
                                        :get,
                                        :lock,
                                        :mkcol,
                                        :mkredirectref,
                                        :move,
                                        :post,
                                        :propfind,
                                        :propfind_acl,
                                        :propfind_cups,
                                        :proppatch,
                                        :put,
                                        :rebind,
                                        :search,
                                        :unbind,
                                        :uncheckout,
                                        :unlock,
                                        :updateredirectref,
                                        :version_control
                                        )
      
      ############################################################

      def base_url() @global_opts[:base_url]; end
      
      # tries at most one request which may return a 401
      def try_request httpmethod, uri, stream, auth, options
        requesturl = uri.path
        requesturl = requesturl + "?" + uri.query unless uri.query.nil?
        request = RubyDav::get_request_class(httpmethod).new requesturl

        (%w(destination if_match if_none_match if_modified_since) +
         %w(if_unmodified_since)).each do |k|
          add_request_header request, options, k
        end

        add_request_header request, options, :overwrite do |v|
          v == false ? "F" : "T"
        end
        
        add_request_header request, options, :depth do |v|
          v == INFINITY ? 'infinity' : v.to_s
        end

        add_request_header request, options, :timeout do |v|
          v == INFINITY ? 'Infinite, Second-4100000000' : 'Second-' + v.to_s
        end

        add_request_header(request, options, :lock_token) { |v| "<#{v}>" }

        add_request_header(request, options, :if) do |v|
          strict_if = options[:strict_if] == false ? false : true

          if v.is_a? Hash
            v2 = {}
            v.each do |k, v|
              v2[fullurl(k)] = v
            end
            v = v2
          end
          
          IfHeader.if_header strict_if, v
        end

        add_request_header(request, options, :cookie) do |v|
          cookies = []
          v.each{|n,v| cookies << ""+n.to_s+"="+v }
          cookies.join ","
        end

        add_request_header(request, options, :apply_to_redirect_ref) do |v|
          v ? "T" : "F"
        end

        add_request_header(request, options, :accept_encoding)

        add_request_header(request, options, :x_requested_with)

        unless stream.nil?
          add_request_header request, options, :content_type
          request.add_field('Expect', '100-continue')
          #            request.add_field('Transfer-Encoding', 'chunked')
          stream.rewind if stream.respond_to?(:rewind)
          request.body_stream = stream
          request.add_field('Content-Length', stream.size)
        end
        
        request.add_field('Authorization', auth.authorization(request.method, requesturl)) unless auth.nil?

        http_response = @connection_pool.request(uri, request)

        @logger.debug { http_response.body }
        ResponseFactory.get(uri.path, http_response.code, http_response.to_hash,
                            http_response.body, httpmethod)
      end

      def response_to_auth response, uri, options
        username, password, basic_creds, digest_a1, realm, force_basic_auth =
          options.values_at(:username, :password, :basic_creds,
                            :digest_a1, :realm, :force_basic_auth)

        auth = basic_auth = digest_auth = nil

        response.get_fields('WWW-Authenticate').each do |www_auth_hdr|
          auth = Auth.construct www_auth_hdr
          next if realm && auth.realm != realm
          case auth
          when DigestAuth
            digest_auth = auth
            break  # (sic) break out of the loop
          when BasicAuth
            basic_auth = auth if basic_auth.nil?
          end
        end

        if digest_auth
          auth = digest_auth

          raise "must pass username for digest auth" if username.nil?
          auth.username = username
          
          if digest_a1
            auth.h_a1 = digest_a1
          elsif password
            auth.password = password
          else
            raise "must pass password or digest_a1 for Digest Auth"
          end
          
        elsif basic_auth
          
          raise SecurityError, "Refusing to use basic auth over an unencrypted connection" unless
            uri.is_a?(URI::HTTPS) || uri.host == "localhost" || force_basic_auth
          auth = basic_auth

          if basic_creds
            auth.creds = basic_creds
          elsif username && password
            auth.username = username
            auth.password = password
          else
            raise "must pass (username and password) or basic_creds for Basic Auth"
          end
        end

        return auth
      end
      
      
      
      def try_authenticated_request httpmethod, uri, stream, prev_response, options
        auth, realm = options.values_at(:auth, :realm)
        auth ||= response_to_auth prev_response, uri, options
        return nil unless auth
        
        response = try_request(httpmethod, uri, stream, auth, options)      

        raise "server returned incorrect rspauth" if
          (auth.is_a?(DigestAuth) &&
           (auth_info = response.get_field('Authentication-Info')) &&
           !auth.validate_auth_info(auth_info))

        @auth_world.add_auth auth, uri.to_s, options unless realm && auth.realm != realm  

        return response
      end

      def request(httpmethod, url = "", stream = nil, options = {})
        if options.include? :destination
          options[:destination] = fullurl options[:destination]
        end
        
        unless stream.nil? || options.include?(:content_type)
          mimetype = stream.is_a?(File) ? MIME.check(stream.path) : MIME.check_magics(stream)
          options[:content_type] = mimetype.nil? ? 'text/plain' : mimetype.type
        end
        
        options = merge_request_options options
        uri = URI.join(options[:base_url], url)

        
        auth = @auth_world.get_auth uri.to_s, options
        response1 = try_request httpmethod, uri, stream, auth, options

        response2 = try_authenticated_request(httpmethod, uri, stream, response1, options) if
          response1.unauthorized? && (options[:username] || options[:basic_creds])

        # try a 3rd time if it's a 401 where the nonce is stale
        response3 = nil
        if response2 && response2.unauthorized?
          auth = response_to_auth response2, uri, options
          response3 = try_authenticated_request(httpmethod, uri, stream, response2,
                                                options.merge( :auth => auth )) if
            auth && auth.stale?
        end
        
        response = response3 || response2 || response1

        if response.status == '503' and options[:retry_on503] and response.headers['retry-after']
          @retry_num ||= 1
          if @retry_num < options[:retry_on503]
            sleep(response.headers['retry-after'].to_s.to_i/100)
            @retry_num += 1
            response = request(httpmethod, url, stream, options)
          end
        end
        response
      end

      def add_request_header request, options, key, &block
        value = options[key.to_sym]
        unless value.nil?
          req_key = key.to_s.gsub /_/, '-'
          req_value = block_given? ? yield(value) : value
          request.add_field req_key, req_value
        end
      end

      def generate_props_xml xml, props
        props.each { |p| PropKey.strictly_prop_key(p).printXML(xml) }
      end
      
      def generate_propfind_bodystream *props
        return RubyDav.build_xml_stream do |xml|
          xml.D(:propfind, "xmlns:D" => "DAV:") do
            if props.include? :propname
              xml.D :propname
            elsif props.include? :allprop
              xml.D :allprop
              remaining_props = props.reject { |p| p == :allprop }
              xml.D(:include) do
                generate_props_xml xml, remaining_props
              end unless remaining_props.empty?
            else
              xml.D(:prop) { generate_props_xml xml, props }
            end
          end
        end
      end

      def generate_expand_property_report(xml, eprophash)
        eprops.each do |eprop, value|
          xml.D(:property, "name" => eprop) do
            generate_expand_property_report(xml, value) if value
          end
        end
      end

      # Options:
      # * <tt>:base_url</tt> => Base URL
      # * <tt>:username</tt> => username to authenticate with
      # * <tt>:password</tt> => password to authenticate with
      # * <tt>:basic_creds</tt> => base64 encoding of username:password.  Can be used in place of :username and :password for basic auth
      # * <tt>:digest_a1</tt> => hash (usually MD5) of username:realm:password.  Can be used in place of :password for digest auth
      # * <tt>:realm</tt> => authentication realm (optional)
      # * <tt>:digest_session</tt> => File to store and load digest session info
      # * <tt>:force_basic_auth</tt> => <tt>true</tt> | <tt>false</tt> (defaults to <tt>false</tt>)
      #
      # For digest auth, the password equivalent is the hash (usually MD5) of A1
      # (username:realm:password).  It can be used in place of a
      # :password
      #
      # For basic auth, the password equivalent is a base64 encoding of
      # username:password.  It can be used in place of :username and
      # :password
      
      def initialize options = {}
        options = { :base_url => '', :log_level => 'INFO' }.merge options
        @global_opts = options
        @auth_world = AuthWorld.new
        @connection_pool = ConnectionPool.new

        @logger = Log4r::Logger.new "RubyDav Request #{object_id}"
        @logger.outputters = Log4r::Outputter.stdout
        @logger.level = Log4r.const_get options[:log_level].upcase
      end

      def fullurl url
        URI.join(@global_opts[:base_url], url).to_s
      end

      private

      # returns merge of options with @global_opts
      # resolves conflicts between some options
      def merge_request_options options
        options2 = @global_opts.merge options

        # resolve conflict between :digest_a1 and :password options
        # by taking the on given in this request call
        if options2.include?(:digest_a1) && options2.include?(:password)
          if @global_opts.include? :digest_a1
            raise("both digest_a1 and password specified " +
                  "when Request was created") if
              @global_opts.include? :password
            options2.delete :digest_a1
          elsif @global_opts.include? :password
            options2.delete :password
          else
            # both options must have been specified at call time
            raise "both digest_a1 and password specified"
          end
        end
        return options2
      end
      

    end
  end
end
