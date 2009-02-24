require 'optparse'

require 'lib/rubydav'
require 'test/integration/webdavtestutils'

require '../inspector/lib/inspector'

module WebDavTestSetup
  include WebDavTestUtils
  def webdavtestsetup
    @@force_basic = false

    OptionParser.new do |opts|
      opts.banner = "Usage: ts_webdav.rb [options]"
      
      opts.on("-u", "--user USERNAME", "Username") do |u|
        @@username = u
      end
      opts.on("-p", "--password PASSWORD", "Password") do |p|
        @@password = p
      end
      opts.on("-s", "--server SERVER", "Server Address") do |s|
        @@host = s
      end
      opts.on("-b", "--allow-basic", "Allow Basic Authentication over unencrypted, remote connections") do |b|
        @@force_basic = b
      end
      opts.on_tail("-h", "--help", "Show this message") do
        puts opts
        exit
      end
    end.parse!

    @username = @@username
    @password = @@password
    @host = @@host

    @uri = URI.parse(@host)
    @creds = {:username=>@username, :password => @password, :force_basic_auth => @@force_basic} 
    @request = RubyDav::Request.new @creds.merge(:base_url => @host)

    @filebody = File.read 'test/integration/webdavtestsetup.rb'
    @filesize = File.size 'test/integration/webdavtestsetup.rb'
    @stream = StringIO.new @filebody
    @bigfilepath = 'test/integration/data/bigfile'
  end

  # creds for 'test' user
  # NOTE: specific to limestone
  def testcreds
    {:username=>"test2", :password => "test2"}
  end

  def admincreds
    {:username => 'limestone', :digest_a1 => 'f2f2fba55068596de02a6771b8b9d13c'}
  end
  
  # test user's home directory
  # NOTE: specific to limestone
  def testhomepath
    '/home/test2/'
  end

  def testhome
    baseuri + testhomepath
  end

  # NOTE: specific to limestone
  def test_principal_uri
    baseuri + get_principal_uri('test2')
  end

end
