require File.dirname(__FILE__) + '/errors'
require File.dirname(__FILE__) + '/utility'

module RubyDav

  class DavError

    attr_reader :name, :element

    def initialize element
      raise BadResponseError unless RubyDav.node_has_name? element, 'error'
      @element = element
      @name = element.name
    end

    def self.parse element
      return new(element)
    rescue BadResponseError
      return nil
    end

  end
  

end
