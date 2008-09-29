module RubyDav
  class LockInfo
    attr_reader :type, :scope, :depth, :timeout, :owner, :token, :root
    attr_writer :root

    def initialize(lockinfo={})
      @type = lockinfo[:type] || :write
      @scope = lockinfo[:scope] || :exclusive
      @depth = lockinfo[:depth] || INFINITY
      @timeout = lockinfo[:timeout] || INFINITY
      @owner = lockinfo[:owner] || "RubyDav Tests"
      @token = lockinfo[:token]
    end

    def printXML(xml)
      xml.D(:lockinfo, "xmlns:D" => "DAV:") do
        xml.D :locktype do
          xml.D @type
        end
        xml.D :lockscope do
          xml.D @scope
        end
        xml.D :owner, @owner_info
      end
    end
  end

end
