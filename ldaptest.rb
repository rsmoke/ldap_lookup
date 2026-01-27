#!/usr/bin/env ruby

# Load .env file if it exists (for local development)
begin
  require 'dotenv/load'
rescue LoadError
  # dotenv not available, will use environment variables or fallbacks
end

require_relative "lib/ldap_lookup"

class Ldaptest
  include LdapLookup

  ############## CONFIGURATION BLOCK ###################
  LdapLookup.configuration do |config|
    config.host = ENV['LDAP_HOST'] || "ldap.umich.edu"
    config.port = ENV['LDAP_PORT'] || "389"
    config.base = ENV['LDAP_BASE'] || "dc=umich,dc=edu"
    config.username = ENV['LDAP_USERNAME'] || 'your_uniqname'
    config.password = ENV['LDAP_PASSWORD'] || 'your_password'
    # Read encryption from ENV, default to start_tls
    encryption_str = ENV['LDAP_ENCRYPTION'] || 'start_tls'
    config.encryption = encryption_str.to_sym
    config.dept_attribute = "umichPostalAddressData"
    config.group_attribute = "umichGroupEmail"
    # Enable LDAP debug logging in this test runner
    debug_str = ENV['LDAP_DEBUG']
    config.debug = debug_str ? debug_str.to_s.downcase == 'true' : true
  end
  #######################################################

  def initialize(name = nil)
    @uid = name
    @group_uid = nil
  end

  def reset_uid
    puts "Enter a valid UID"
    @uid = gets.chomp.to_s
    return "UID is now set to #{@uid}"
  end

  def reset_group_uid
    puts "Enter a valid group_name"
    @group_uid = gets.chomp.to_s
    return "group_name is now set to #{@group_uid}"
  end

  def result_box(answer)
    print "\e[2J\e[f"
    2.times { puts " " }
    puts "Your Results"
    puts "======================================================"
    puts " "
    puts "#{answer}"
    puts " "
    puts "======================================================"
    puts "current values:\n UID set to=> #{@uid}\n group_uid set to=> #{@group_uid}"
    puts "------------------------------------------------------"
    2.times { puts " " }
  end

  def timestamp
    Time.now.asctime
  end

  def prompt_for_action
    puts "What would you like to do?"
    puts "================================="
    puts "1: set new uid"
    puts "2: set new group_uid"
    puts "+++++++++++++++++++++++++"
    puts "3: get users full name"
    puts "33: check if uid exists"
    puts "4: get users department"
    puts "5: get users email"
    puts "55: get all groups a user is a member of"
    puts "+++++++++++++++++++++++++"
    puts "6: get ldap group-name member listing"
    puts "7: check if uid is member of a group"
    puts "+++++++++++++++++++++++++"
    puts "8: what time is it?"
    puts "99: test LDAP connection (diagnostic)"
    puts "0: exit"
    puts ""
    print "Enter a number: "

    case gets.chomp.to_i
    when 1 then result_box(reset_uid)
    when 2 then result_box(reset_group_uid)
    when 3 then result_box(LdapLookup.get_simple_name(@uid))
    when 33 then result_box(LdapLookup.uid_exist?(@uid))
    when 4 then result_box(LdapLookup.get_dept(@uid))
    when 5 then result_box(LdapLookup.get_email(@uid))
    when 55 then result_box(LdapLookup.all_groups_for_user(@uid))
    when 6 then result_box(LdapLookup.get_email_distribution_list(@group_uid))
    when 7 then result_box(LdapLookup.is_member_of_group?(@uid, @group_uid))
    when 8 then result_box(timestamp)
    when 99 then result_box(LdapLookup.test_connection.inspect)
    when 0 then puts "you chose exit!"
throw(:done)
    else
      print "\e[2J\e[f"
      puts "====> Please type 1,2,3,33,4,5,55,6,7,8 or 0 only"
      2.times { puts " " }
    end
  end

  def run
    catch(:done) do
      loop do
        prompt_for_action
      end
    end
  end
end

print "\e[2J\e[f"
print "Enter a valid UID=> "
name = gets.chomp.to_s
program1 = Ldaptest.new(name).run
