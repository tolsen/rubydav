# $URL$
# $Id$

module RubyDav
  module IfHeader

    class << self

      # can be called with one of the following
      # 1. hash of strings to token
      # 2. hash of strings to array of tokens
      # 3. hash of strings to array of array of tokens
      # 4. tokens
      # 5. token arrays
      # where a token is an etag (with quotes, but without square brackets)
      #                  or lock-token (without angle brackets)
      #                  or :not
      
      def if_header strict_if = true, *args
        tags = args[0].is_a?(Hash) ? args[0] : { :untagged => args }

        header = tags.map do |k, v|
          tag = k == :untagged ? "" : "<#{k}> "

          if v.is_a?(Array)
            if v[0].is_a?(Array)
              if v[0][0].is_a?(Array) # triple nested
                v = v[0]
              end
              # else double nested array (do nothing)
            else # single nested
              v = [ v ]
            end
          else # single item
            v = [ [ v ] ]
          end
          
          v << [ :not, "DAV:nolock" ] unless strict_if
          
          tag + (v.map do |tkns|
                   "(" + tkns.map do |t|
                     case t
                     when :not then "Not"
                     when String then tokenize(t)
                     else raise ArgumentError, "token must be string or :not"
                     end
                   end.join(' ') + ")"
                 end.join ' ')
        end.join ' '
      end

      # adds square brackets around etags
      # and angle brackets around lock tokens
      def tokenize string
        string = string.strip
        return "[#{string}]" if string =~ /^(W\/)?".*"$/
        return "<#{string}>"
      end
      

    end
  end
end
