require 'test/test_helper'

class RubyDavFunctionalTestCase < RubyDavTestCase
  
  HTTP_CODE_TO_CLASS = {
    "200" => RubyDav::OkResponse,
    "201" => RubyDav::CreatedResponse,
    "204" => RubyDav::NoContentResponse,
    "207" => RubyDav::MultiStatusResponse,
    "400" => RubyDav::BadRequestError,
    "401" => RubyDav::UnauthorizedError,
    "403" => RubyDav::ForbiddenError,
    "404" => RubyDav::NotFoundError,
    "405" => RubyDav::MethodNotAllowedError,
    "408" => RubyDav::RequestTimeoutError,
    "409" => RubyDav::ConflictError,
    "412" => RubyDav::PreconditionFailedError,
    "413" => RubyDav::RequestEntityTooLargeError,
    "414" => RubyDav::RequestUriTooLargeError,
    "415" => RubyDav::UnsupportedMediaTypeError,
    "500" => RubyDav::InternalServerError,
    "501" => RubyDav::NotImplementedError,
    "503" => RubyDav::ServiceUnavailableError,
    "505" => RubyDav::HttpVersionNotSupportedError,
    "507" => RubyDav::InsufficientStorageError
  }
  
  def self.create_tests(method,*errorcodes)
    errorcodes.each do |code|
      define_method "test_#{method}_#{code}" do 
        response = send("get_response_to_mock_#{method}_request",code)
        send("assert_valid_#{method}_response",response,code)
      end
    end
  end

  def self.method_missing( method, *arguments )
    return super unless /create_\w*_tests/.match( method.to_s )
    dav_method = method.to_s.sub( /^create_(\w*)_tests/, '\1' )
    create_tests(dav_method,*arguments)
  end
  
end
