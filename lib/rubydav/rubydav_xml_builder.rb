require 'rubygems'
require 'builder'

module RubyDav
  class XmlBuilder
    def self.generate(target = nil)
      xml = nil

      if target
        xml = ::Builder::XmlMarkup.new(:indent => 2, :target => target)
      else
        xml = ::Builder::XmlMarkup.new(:indent => 2)
      end

      xml.instruct!
      xml
    end

  end
end


