require_relative 'helpers/configuration'
require 'net/ldap'

module LdapLookup
  extend Configuration

  define_setting :host
  define_setting :port, '389'
  define_setting :base
  define_setting :dept_attribute
  define_setting :group_attribute

  def self.get_ldap_response(ldap)
    response = ldap.get_operation_result
    raise "Response Code: #{response.code}, Message: #{response.message}" unless response.code.zero?
  end

  def self.ldap_connection
    Net::LDAP.new(
      host: host,
      port: port,
      base: base,
      auth: { method: :anonymous }
    )
  end

  def self.get_user_attribute(uniqname, attribute)
    ldap = ldap_connection
    search_param = uniqname
    result_attrs = [attribute]

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      value = item[attribute]&.first
      return value unless value.nil?
    end

    "No #{attribute} found for #{uniqname}"
  ensure
    get_ldap_response(ldap)
  end

  def self.get_nested_attribute(uniqname, nested_attribute)
    ldap = ldap_connection
    search_param = uniqname
    # Specify the full nested attribute path using dot notation
    result_attrs = [nested_attribute.split('.').first]
  
    search_filter = Net::LDAP::Filter.eq('uid', search_param)
  
    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      # Split the string into key-value pairs
      if string1 = item[nested_attribute.split('.').first]&.first
        key_value_pairs = string1.split('}:{')
        # Find the key-value pair for addr1
        target_pair = key_value_pairs.find { |pair| pair.include?("#{nested_attribute.split('.').last}=") } 
        # Extract the target value
        target_pair_value = target_pair.split('=').last
        return target_pair_value unless target_pair_value.nil?
      end
    end
    "No #{nested_attribute} found for #{uniqname}"

  ensure
    get_ldap_response(ldap)
  end
  

  def self.get_simple_name(uniqname)
    get_user_attribute(uniqname, 'displayname')
  end

  def self.get_email(uniqname)
    get_user_attribute(uniqname, 'mail')
  end

  def self.get_dept(uniqname)
    get_nested_attribute(uniqname, 'umichpostaladdressdata.addr1')
  end

  def self.is_member_of_group?(uid, group_name)
    ldap = ldap_connection
    search_param = group_name
    result_attrs = ['member']

    search_filter = Net::LDAP::Filter.join(
      Net::LDAP::Filter.eq('cn', search_param),
      Net::LDAP::Filter.eq('objectClass', 'group')
    )

    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      members = item['member']
      return true if members&.any? { |entry| entry.split(',').first.split('=')[1] == uid }
    end

    false
  ensure
    get_ldap_response(ldap)
  end

  def self.get_email_distribution_list(group_name)
    ldap = ldap_connection
    result_hash = {}

    search_param = group_name
    result_attrs = %w[cn umichGroupEmail member]

    search_filter = Net::LDAP::Filter.join(
      Net::LDAP::Filter.eq('cn', search_param),
      Net::LDAP::Filter.eq('objectClass', 'group')
    )

    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      result_hash['group_name'] = item['cn']&.first
      result_hash['group_email'] = item['umichGroupEmail']&.first
      members = item['member']&.map { |individual| individual.split(',').first.split('=')[1] }
      result_hash['members'] = members&.sort || []
    end

    result_hash
  ensure
    get_ldap_response(ldap)
  end

  def self.all_groups_for_user(uid)
    ldap = ldap_connection
    result_array = []

    result_attrs = ['dn']

    ldap.search(filter: "member=uid=#{uid},ou=People,dc=umich,dc=edu", attributes: result_attrs) do |item|
      item.each { |key, value| result_array << value.first.split('=')[1].split(',')[0] }
    end

    result_array.sort
  ensure
    get_ldap_response(ldap)
  end
end