require 'set'
require 'uri'

require File.dirname(__FILE__) + '/prop_key'
require File.dirname(__FILE__) + '/property_result'
require File.dirname(__FILE__) + '/utility'

module RubyDav
  
  # An Ace grants or denies a list of privileges to a principal on a resource
  class Ace
    # action will be either :grant or :deny
    attr_reader :action
    
    # principal can be a url, :all, :authenticated, :unauthenticated, propkey, or :self
    attr_reader :principal
    
    # a protected ace may not be removed or changed
    def protected?
      @isprotected
    end
    
    # privileges is a list eg. :read-acl, :read, :write, ...
    attr_reader :privileges

    def initialize(action, principal, isprotected, *privileges)
      @privileges = self.class.normalize_privileges *privileges
      @isprotected = isprotected
      principal = PropKey.strictly_prop_key principal if ((Symbol === principal) &&
                                                          (principal != :all) &&
                                                          (principal != :authenticated) &&
                                                          (principal != :unauthenticated) &&
                                                          (principal != :self))
      @principal = principal
      @action = action
    end
    
    def compactable?(ace)
      (self.class == ace.class) && 
        (@action == ace.action) &&
        (@principal == ace.principal) && 
        (@isprotected == ace.protected?)
    end
    
    def ==(other)
      (self.class == other.class) &&
        (@action == other.action) &&
        (@principal == other.principal) &&
        (@isprotected == other.protected?) &&
        (@privileges.sort == other.privileges.sort)
    end
    alias eql? ==

    def hash
      return ("#{self.class.hash}/#{@action.hash}/#{@principal.hash}" +
              "/#{@isprotected.hash}/#{@privileges.hash}").hash
    end
      
    def to_xml(xml = nil)
      return RubyDav::build_xml(xml) do |xml, ns|
        xml.D :ace, ns do
          xml.D :principal do
            if Symbol === @principal
              xml.D @principal
            elsif PropKey === @principal
              xml.D(:property) do
                @principal.to_xml(xml)
              end
            else
              xml.D(:href, @principal)
            end
          end
          xml.D(action) do
            @privileges.each do |priv| 
              xml.D :privilege do
                PropKey.strictly_prop_key(priv).to_xml xml
              end
            end
          end
          xml.D(:protected) if protected?
          if InheritedAce === self
            xml.D(:inherited) { xml.D(:href, @url)}
          end
        end
      end
    end
    
    def addprivileges(privileges)
      @privileges |= self.class.normalize_privileges(*privileges)
    end

    def to_s
      'Action: ' + @action.to_s + ' Principal: ' + @principal.to_s +
      ' Protected: ' + (@isprotected ? 'T':'F') + ' Privileges: ' +
      @privileges.inject(' ') {|privs, p| privs += p.to_s}
    end

    # removes hostname from the principal
    def generalize_principal!
      @principal = RubyDav.generalize_principal @principal if
        @principal.is_a? String
      return self
    end

    class << self

      def from_elem elem
        nodes = RubyDav.dav_elements_hash(elem, 'protected', 'inherited',
                                          'principal', 'grant', 'deny')

        protected = nodes.include? 'protected'
          
        raise 'no principal element found' unless nodes.include? 'principal'
        principal = parse_principal_element nodes['principal']

        action_elem = nodes['grant']
        if nodes.include? 'deny'
          raise 'cannot specify both grant and deny at the same time' unless
            action_elem.nil?
          action_elem = nodes['deny']
        else
          raise 'no grant or deny element found' if action_elem.nil?
        end

        action = action_elem.name.to_sym
        privileges = RubyDav.privilege_elements_to_propkeys action_elem
        
        if nodes.include? 'inherited'
          inherited_url = RubyDav.first_element_named(nodes['inherited'], 'href').content
          return InheritedAce.new(inherited_url.to_s, action, principal,
                                  protected, *privileges)
        else
          return Ace.new(action, principal, protected, *privileges)
        end
      end

      def normalize_privileges *privileges
        privileges.map do |p|
          p = p.to_sym if p.is_a? String
          next PropKey.strictly_prop_key(p)
        end
      end

      def parse_principal_element principal_elem
        child = RubyDav.first_element principal_elem
        raise "child of <principal> needs to be in the DAV: namespace" unless
          RubyDav.namespace_href(child) == 'DAV:'

        case child.name
        when 'all', 'authenticated', 'unauthenticated', 'self'
          return child.name.to_sym
        when 'href'
          return child.content
        when 'property'
          grandchild = RubyDav.first_element child
          return RubyDav.element_to_propkey(grandchild)
        else
          raise "unrecognized child of principal element: #{principal_elem.to_s}"
        end
      end

    end
  end
  
  # An inherited ace is inherited from another resource.
  class InheritedAce < Ace
    # url from which this ace is inherited
    attr_reader :url
    
    def initialize(inheritedurl, action, principal, isprotected, *privileges)
      @url = inheritedurl
      super(action, principal, isprotected, *privileges)
    end
    
    def ==(other)
      super(other) && 
        (@url == other.url)
    end
    
    def compactable?(other)
      super(other) && 
        (@url == other.url)
    end

    def to_s
      super + ' Inherited: T'
    end
  end

  
  # Acl is a list of aces.
  class Acl < Array
    # If true, upon addition adjacent aces that share the same action and principal are grouped together.
    def compacting?
      @compact
    end
    
    def compacting=(bool)
      @compact = bool
    end
    
    def unshift(ace)
      if @compact && self.size>0 && self[0].compactable?(ace)
        ace.addprivileges(self[0].privileges)
        self[0] = ace
      else
        super
      end
    end

    def compact!
      if size > 0
        compacting_ace = self[0]

        (1..(size - 1)).each do |i|
          if compacting_ace.compactable? self[i]
            compacting_ace.addprivileges self[i].privileges
            self[i] = nil
          else
            compacting_ace = self[i]
          end
        end
      end
      
      super
    end

    def generalize_principals!
      each { |p| p.generalize_principal! }
      return self
    end
    
    def to_xml(xml)
      xml.D(:acl, "xmlns:D" => "DAV:") do
        self.each { |ace| ace.to_xml(xml) }
      end
    end
    
    def ==(other)
      (self.class == other.class) &&
        super(other)
    end
    alias :eql? :==

    def inherited
      Acl[*select { |ace| ace.is_a? InheritedAce }]
    end
  
    def modifiable
      Acl[*reject { |ace| ace.is_a?(InheritedAce) || ace.protected? }]
    end

    def protected
      Acl[*select { |ace| ace.protected? }]
    end

    class << self
      
      def from_elem elem
        aces = RubyDav.elements_named(elem, 'ace').map { |e| Ace.from_elem e }
        return Acl[*aces]
      end
      
    end

    PropertyResult.define_class_reader :acl, self, 'acl'
    
  end
end
