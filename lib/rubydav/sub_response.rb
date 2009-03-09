
module RubyDav

  class SubResponse

    attr_reader :href, :status, :error, :description, :location

    def initialize href, status, error = nil, description = nil, location = nil
      @href = href
      @status = status
      @error = error
      @description = description
      @location = location
    end

    def success?
      status =~ /^2\d\d$/
    end

  end

end
