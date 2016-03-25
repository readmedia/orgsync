require "orgsync/version"
require 'open-uri'
require 'openssl'
require 'base64'

#
# Simple API wrapper for OrgSync; see: https://orgsync.com/api/docs/v2/
#
module OrgSync
  #
  # Base API class; encapsulates low-level methods for communicating witih OrgSync
  #
  class Base
    API_VERSION = "v2"
    
    def self.request(path, params, key)
      endpoint = "https://api.orgsync.com/api/#{API_VERSION}/"
      
      default_params = {:key => key}
      params = default_params.merge(params)
      
      url  = "#{endpoint}#{path}?#{params.to_query}"
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
  
      # Output requests to stnadard output to aid in debugging
      http.set_debug_output($stdout)
  
      # Required by OrgSync for all API calls
      if uri.scheme == "https"
        http.use_ssl = true
      end
      
      # Note, our connection is READ-ONLY; only supporting GET requests
      request = Net::HTTP::Get.new(uri.request_uri)
      res = http.request(request)
    
      if res.code.to_i == 200
        return JSON.parse(res.body)
      else
        puts res.body
        raise Exception.new("#{res.code} - #{res.message}")
      end
    end
  end
  
  #
  # Base API Object class; dyanmically creates setters and getters based on 
  # the keys in the JSON returned by the API. This way if they add or remove 
  # attributes from objects we won't have to update this class.
  #
  class Object < OrgSync::Base
    attr_accessor :api_key, :orgsync_attributes, :json
    
    def initialize(json, key)
      @json    = json
      @api_key = key
      @orgsync_attributes = []
      
      json.keys.each { |attrib| 
        add_accessors(attrib)
        send("#{attrib}=", json[attrib])
      }
      self
    end
    
    def self.find(id, params, key)
      if id.blank?
        raise "Cannot find #{self.class.split('::').last} without id" 
      else
        if id == :all
          OrgSync::Base.request(self.endpoint, params, key).map { |json| 
            new(json, key) 
          }
        else
          new(OrgSync::Base.request(self.endpoint + "/#{id}", params, key), key)
        end
      end
    end
    
    def reload
      reloaded = self.class.find(self.id, {}, @api_key)
      reloaded.orgsync_attributes.each { |attrib| 
        # The API returns partial objects in some cases so we need to add any
        # new methods for attributes that were not initially there
        add_accessors(attrib) unless defined?(attrib)
        send("#{attrib}=", reloaded.send(attrib))
      }
      self
    end
    
    private
      
      def add_accessors(attrib)
        @orgsync_attributes << attrib

        self.class.send(:define_method, "#{attrib}=") do |val|
          instance_variable_set("@#{attrib}", val)
        end

        self.class.send(:define_method, attrib) do
          instance_variable_get("@#{attrib}")
        end
      end
  end
  
  #
  # Represents a club or activity; OrgSync calls these Organizations
  # https://orgsync.com/api/docs/v2/orgs
  # 
  class Organization < OrgSync::Object
    def self.endpoint
      "orgs"
    end
    
    def membership_logs
      @membership_logs ||= OrgSync::MembershipLog.find(:all, {:org_id => self.id}, @api_key)
    end
    
    # Returns all accounts both current and past from what I can tell. 
    # These accounts then needs to be cross referenced with their 
    # Membership Logs for this Organization.
    def accounts
      return [] if self.id.blank?
      @accounts ||= 
        OrgSync::Base.request("#{self.class.endpoint}/#{self.id}/accounts", {}, @api_key).map { |json| 
          OrgSync::Account.new(json, @api_key) 
        }
    end
  end
  
  #
  # Represents a student (or user) in OrgSync
  # https://orgsync.com/api/docs/v2/accounts
  #
  class Account < OrgSync::Object
    def self.endpoint
      "accounts"
    end
    
    def organizations
      return [] if self.id.blank?
      reload unless respond_to?(:org_ids)
      # Oddly, there is no API call for getting a list of organizations given 
      # an Account, so, we have to load them all one by one like this...
      @organizations ||= 
        self.org_ids.map { |oid| 
          OrgSync::Organization.find(oid, {}, @api_key) 
        }
    end
    
    # Returns membership logs in order of the date they were created
    def membership_logs(org = nil)
      @membership_logs ||= {}
      key = org.blank? ? :all : org.id
      
      params = {:account_id => self.id}
      params = params.merge({:org_id => org.id}) if org
      
      @membership_logs[key] ||= 
        OrgSync::MembershipLog.find(:all, params, @api_key).sort { |l1, l2| 
          l1.created_at <=> l2.created_at 
        }
    end
  end
  
  #
  # When an Account "joins" or "leaves" an Organization a MembershipLog is created.
  # However, it doesn't loook like "leave" events are always logged. My guess is 
  # that the student (or admin) has to explicitly remove a student for this event
  # to be logged which doesn't look like it always happens. Not sure how to tell
  # if an Account is a current, past or non-member of a given Organization. 
  # https://orgsync.com/api/docs/v2/org_membership_log_entries
  #
  class MembershipLog < OrgSync::Object
    def self.endpoint
      "org_membership_log_entries"
    end
    
    def join?
      self.action.downcase == "join"
    end
    
    def leave?
      self.action.downcase == "leave"
    end
  end
  
  class Classification < OrgSync::Object
    def self.endpoint
      "classifications"
    end
    
    def accounts
      OrgSync::Base.request("#{self.class.endpoint}/#{self.id}/accounts", {}, @api_key).map { |json| 
        OrgSync::Account.new(json, @api_key)
      }
    end
  end
end
