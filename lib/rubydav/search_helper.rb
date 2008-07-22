require File.dirname(__FILE__) + '/prop_key'
require 'rubygems'
require 'builder'

module SearchHelper
  
  COMP_OPS = ["gt", "lt", "eq", "lte", "gte", "like"]
  LOG_OPS = ["and", "or", "not"]

  def generate_ops
    # generate comparision operators gt, lt, ....
    COMP_OPS.each do |op|
        def_op = <<END_OF_DEF
          def #{op}(propkey, literal)
            xmlstr = ""
            xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
            propkey = RubyDav::PropKey.strictly_prop_key(propkey)
            xml.D(:#{op}) do
              xml.D(:prop) { propkey.printXML xml }
              xml.D(:literal, literal.to_s)
            end
            return xmlstr
          end
END_OF_DEF

      instance_eval(def_op)
    end

    # generate logical operators _and, _or, _not ....
    LOG_OPS.each do |op|
      def_op = <<END_OF_DEF
        def _#{op}(*operands)
          xmlstr = ""
          xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
          xml.D(:#{op}) { xml << operands.join }
          return xmlstr
        end
END_OF_DEF
    
    instance_eval(def_op)
    end
  end

  def is_collection
    xmlstr = ""
    xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
    xml.D(:"is-collection")
    return xmlstr
  end

  def is_defined propkey
    xmlstr = ""
    xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
    xml.D(:"is-defined") do
      xml.D(:prop) { propkey.printXML xml }
    end
    return xmlstr
  end

end
