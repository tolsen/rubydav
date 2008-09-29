require File.dirname(__FILE__) + '/rexml_fixes'

module DavErrorHandler
    class DavError
        attr_reader :condition, :details

        def initialize(condition, details=nil)
            @condition = condition
            @details = details
        end
    end

    def self.parse_dav_error(error_elem)
        return nil unless (!error_elem.nil? && error_elem.namespace == "DAV:" && error_elem.name == "error")
        
        #pre(post)condition
        errorcondition = REXML::XPath.first(error_elem)

        DavError.new(errorcondition.clone, errorcondition.get_elements(nil))
    end
end
