# $Id$
# $URL$

require 'stringio'

require 'rubygems'
gem 'builder'

require File.dirname(__FILE__) + '/rubydav.rb'

module RubyDav

  class Request

    # options: :new_password, :displayname, :email, :cur_password
    def put_user url, options
      xml = Builder::XmlMarkup.new
      xml.instruct!
      xml.L(:user, "xmlns:L" => "http://limebits.com/ns/1.0/", "xmlns:D" => "DAV:") do
        xml.L(:password, options[:new_password]) if options.include? :new_password
        xml.L(:cur_password, options[:cur_password]) if options.include? :cur_password 

        xml.D(:displayname, options[:displayname]) if options.include? :displayname
        xml.L(:email, options[:email]) if options.include? :email
      end

      stream = StringIO.new xml.target!
      put_opts = options.reject{ |k, v| [:new_password, :displayname, :email].include? k }
      
      return put(url, stream, put_opts)
    end

    def create_user url, new_password, displayname, email, options = {}
      [new_password, displayname, email].each do |arg|
        raise ArgumentError, "neither new_password, displayname, nor email can be nil" if arg.nil?
      end

      put_user_opts = options.merge( :new_password => new_password,
                                     :displayname => displayname,
                                     :email => email,
                                     :if_none_match => '*' )
      return put_user(url, put_user_opts)
    end

    def modify_user url, options = {}
      return put_user(url, options.merge(:if_match => '*'))
    end

    clone_class_from_instance_methods(
                                      :put_user,
                                      :create_user,
                                      :modify_user
                                      )
    
  end

end

      
