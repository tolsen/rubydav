require 'set'

require File.dirname(__FILE__) + '/prop_key'

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
      @privileges = Array.new
      privileges.each do |priv|
        priv = priv.to_sym unless (priv.is_a?(Symbol) || priv.is_a?(PropKey))
        @privileges << priv
      end
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
        (@privileges == other.privileges)
    end
    alias eq? == 
      
    def printXML(xml = nil)
      return RubyDav::buildXML(xml) do |xml, ns|
        xml.D :ace, *ns do
          xml.D :principal do
            if Symbol === @principal
              xml.D @principal
            elsif PropKey === @principal
              xml.D(:property) do
                @principal.printXML(xml)
              end
            else
              xml.D(:href, @principal)
            end
          end
          xml.D(action) do
            @privileges.each do |priv| 
              xml.D :privilege do
                PropKey.strictly_prop_key(priv).printXML xml
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
      @privileges |= privileges
    end

    def to_s
      'Action: ' + @action.to_s + ' Principal: ' + @principal.to_s +
      ' Protected: ' + (@isprotected ? 'T':'F') + ' Privileges: ' +
      @privileges.inject(' ') {|privs, p| privs += p.to_s}
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
    
    def printXML(xml)
      xml.D(:acl, "xmlns:D" => "DAV:") do
        self.each { |ace| ace.printXML(xml) }
      end
    end
    
    def ==(other)
      (self.class == other.class) &&
        super(other)
    end
    alias eq? == 
  end
end
