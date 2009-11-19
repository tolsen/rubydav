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
          def #{op}(propkey, literal, is_bitmark=false)
            xmlstr = ""
            xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
            strict_propkey = RubyDav::PropKey.strictly_prop_key(propkey)
            xml.D(:#{op}) do
              if !is_bitmark
                xml.D(:prop) { strict_propkey.printXML xml }
              else
                xml.LB(:bitmark, "xmlns:LB" => "http://limebits.com/ns/1.0/") do
                  xml.BM(propkey, "xmlns:BM" => "http://limebits.com/ns/bitmarks/1.0/")
                end
              end
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

  def is_bit
    xmlstr = ""
    xml = ::Builder::XmlMarkup.new(:indent => 2, :target => xmlstr)
    xml.LB(:"is-bit", "xmlns:LB" => "http://limebits.com/ns/1.0/")
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
