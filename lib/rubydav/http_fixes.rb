require 'net/http'

module Net

  class HTTP < Protocol
    # Sends an HTTPRequest object REQUEST to the HTTP server.
    # This method also sends DATA string if REQUEST is a post/put request.
    # Giving DATA for get/head request causes ArgumentError.
    # 
    # When called with a block, yields an HTTPResponse object.
    # The body of this response will not have been read yet;
    # the caller can process it using HTTPResponse#read_body,
    # if desired.
    #
    # Returns a HTTPResponse object.
    # 
    # This method never raises Net::* exceptions.
    #
    def request(req, body = nil, &block)  # :yield: +response+
      unless started?
        start {
          req['connection'] ||= 'close'
          return request(req, body, &block)
        }
      end
      if proxy_user()
        unless use_ssl?
          req.proxy_basic_auth proxy_user(), proxy_pass()
        end
      end

      req.set_body_internal body
      begin_transport req
      #req.exec @socket, @curr_http_version, edit_path(req.path)
      req.send_headers @socket, @curr_http_version, edit_path(req.path)

      res = HTTPResponse.read_new(@socket) if req.expecting_100?

#      puts "res is nil" if res.nil?
#      puts "res is continue" if res.kind_of?(HTTPContinue)
      
      if res.nil? || res.kind_of?(HTTPContinue)
        req.send_body @socket
        res = HTTPResponse.read_new(@socket)
      end
      
      res.reading_body(@socket, req.response_body_permitted?) {
        yield res if block_given?
      }
      end_transport req, res

      res
    end
  end
  

  class HTTPGenericRequest

    def expecting_100?
      expect_values = get_fields('Expect')
      return false if expect_values.nil?
      expect_values.any? { |v| v.split(',').any? { |e| e.strip == '100-continue' }}
    end

    def send_headers(sock, ver, path)
      if @body
        self.content_length = body.length
        delete 'Transfer-Encoding'
        supply_default_content_type
      elsif @body_stream
        unless content_length() or chunked?
          raise ArgumentError,
          "Content-Length not given and Transfer-Encoding is not `chunked'"
        end
        supply_default_content_type
      end
      write_header sock, ver, path
    end

    def send_body(sock)
#      puts "has body" if @body
#      puts "has body_stream" if @body_stream

      if @body
        sock.write @body
      elsif @body_stream
        if chunked?
          while s = @body_stream.read(1024)
            sock.write(sprintf("%x\r\n", s.length) << s << "\r\n")
          end
          sock.write "0\r\n\r\n"
        else
          while s = @body_stream.read(1024)
            sock.write s
          end
        end
      end
    end
        

  end
end
