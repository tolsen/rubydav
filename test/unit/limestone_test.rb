require 'lib/limestone'
require 'test/unit/unit_test_helper'

require 'stringio'

class LimestoneTest < RubyDavUnitTestCase

  def setup
    super
    @user_url = "#{@host}/users/timmay"
    @user_path = URI.parse(@user_url).path
  end

  def test_put_user
    mock_put_user_response
    response = RubyDav::Request.put_user(@user_url,
                                         :new_password => 'opensesame',
                                         :displayname => 'Timmay!',
                                         :email => 'timmay@example.com')

    assert_equal '201', response.status
  end

  def test_create_user
    mock_put_user_response do |req|
      assert_equal '*', req['If-None-Match']
    end

    response = RubyDav::Request.create_user(@user_url, 'opensesame', 'Timmay!',
                                            'timmay@example.com')

    assert_equal '201', response.status
  end

  def test_modify_user
    mock_put_user_response '204' do |req|
      assert_equal '*', req['If-Match']
    end
    
    response = RubyDav::Request.modify_user(@user_url,
                                            :new_password => 'opensesame',
                                            :displayname => 'Timmay!',
                                            :email => 'timmay@example.com')

    assert_equal '204', response.status
  end
  

  def mock_put_user_response response = '201', &block
    flexstub(Net::HTTP).new_instances do |http|
      mresponse = mock_response(response)

      validate_put_user = lambda do |req|

        assert_instance_of Net::HTTP::Put, req
        assert_equal @user_path, req.path
        yield req if block_given?
        
        assert_xml_matches req.body_stream.read do |xml|
          xml.xmlns! 'http://limebits.com/ns/1.0/'
          xml.xmlns! :D => 'DAV:'
          xml.user do
            xml.password 'opensesame'
            xml.D :displayname, 'Timmay!'
            xml.email 'timmay@example.com'
          end
        end
      end
      
      http.should_receive(:request).with(on(&validate_put_user)).and_return(mresponse)
        
    end

  end
  

end



      
                                            
