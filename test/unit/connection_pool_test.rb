require 'test/test_helper'

require 'uri'

class ConnectionPoolTestCase < RubyDavTestCase

  include RubyDav

  def setup
    @pool = ConnectionPool.new
    @uri = URI.parse 'http://example.com/'
    @max_attempts = ConnectionPool::MAX_ATTEMPTS
  end

  def test_uri_revolt
    assert_equal 'http://example.com', ConnectionPool.uri_revolt(URI.parse('http://example.com/foo'))
    assert_equal 'http://example.com', ConnectionPool.uri_revolt(URI.parse('http://example.com/'))
    assert_equal 'http://example.com', ConnectionPool.uri_revolt(URI.parse('http://example.com'))
    assert_equal 'https://example.com', ConnectionPool.uri_revolt(URI.parse('https://example.com/foo'))
  end

  def test_brackets   # test_[]
    http = mock_http
    flexmock(Net::HTTP).should_receive(:new).once.with('example.com',80).
      and_return(http)

    assert_equal http, @pool.send(:[], @uri)  # first creates it
    assert_equal http, @pool.send(:[], @uri)  # now it's cached
  end

  def test_delete
    http1, http2 = [mock_http, mock_http]
    
    flexmock(Net::HTTP).should_receive(:new).twice.with('example.com',80).
      and_return(http1, http2)

    assert_equal http1, @pool.send(:[], @uri)  # first creates it
    assert_equal http1, @pool.send(:[], @uri)  # now it's cached
    assert_equal http1, @pool.send(:delete, @uri) # now delete it
    assert_equal http2, @pool.send(:[], @uri)  # now it creates a second
  end

  def test_initialize
    assert_nil @pool.ssl_verify_mode
    pool2 = ConnectionPool.new :ssl_verify_mode => :bogus_mode
    assert_equal :bogus_mode, pool2.ssl_verify_mode
  end

  def test_request
    http = flexmock('http')
    good_request http
    good_request http, 2
    mock_http_constructor http
    assert_two_good_requests
  end

  def test_request_retry
    http = one_request_http
    http2 = flexmock('http2')
    good_request http2, 2
    mock_http_constructor http, http2
    assert_two_good_requests
  end
      
  def test_request_max_possible_retries_without_going_over
    http = one_request_http
    httpees = (2..(@max_attempts-1)).to_a.map { |x| closed_http x }
    httpn = flexmock "http#{@max_attempts}"
    good_request httpn, 2
    httpees.push httpn
    mock_http_constructor http, *httpees
    assert_two_good_requests
  end
  
  def test_request_over_max_possible_retries
    http = one_request_http
    httpees = (2..@max_attempts).to_a.map { |x| closed_http x }
    mock_http_constructor http, *httpees
    
    assert_good_request 1
    assert_bad_request 2
  end

  # helpers

  def mock_http mock = flexmock, ssl = false
    # The code no longer sets use_ssl unless it's true
    #    return mock.should_receive(:use_ssl=).once.with(ssl).mock
    return mock
  end

  def mock_http_constructor *httpees
    httpees.each { |http| mock_http http }
    
    flexmock(Net::HTTP).should_receive(:new).times(httpees.length).
      with('example.com', 80).and_return(*httpees)
  end

  def one_request_http
    http = flexmock('http')
    good_request http
    bad_request http
    http
  end

  def closed_http num
    flexmock('http#{num}') do |mock|
      mock.should_receive(:request).once.with(:request2).and_raise(EOFError)
    end
  end

  def good_request http, num = 1
    http.should_receive(:request).once.ordered.with(request_n(num)).
      and_return(response_n(num))
  end

  def bad_request http, num = 2
    http.should_receive(:request).once.ordered.with(request_n(num)).and_raise(EOFError)
  end

  def assert_good_request num
    assert_equal response_n(num), @pool.request(@uri, request_n(num))
  end

  def assert_bad_request num
    assert_raises(EOFError) { @pool.request(@uri, request_n(num)) }
  end
  
  def assert_two_good_requests
    [1, 2].each { |n| assert_good_request n }
  end

  def request_n(n) "request#{n}".to_sym; end
  def response_n(n) "response#{n}".to_sym; end

    
end
