require_relative 'helpers/configuration'
require 'net/ldap'
require 'openssl'

module LdapLookup
  extend Configuration

  define_setting :host
  define_setting :port, '389'
  define_setting :base
  define_setting :dept_attribute
  define_setting :group_attribute
  define_setting :username
  define_setting :password
  define_setting :bind_dn  # Optional: custom bind DN (for service accounts). If not set, uses uid=username,ou=People,base
  define_setting :encryption, :start_tls  # :start_tls or :simple_tls (LDAPS)

  def self.get_ldap_response(ldap)
    response = ldap.get_operation_result
    raise "Response Code: #{response.code}, Message: #{response.message}" unless response.code.zero?
  end

  def self.ldap_connection
    connection_params = {
      host: host,
      port: port.to_i,
      base: base
    }

    # Configure encryption
    if encryption == :start_tls
      connection_params[:encryption] = {
        method: :start_tls,
        tls_options: { verify_mode: OpenSSL::SSL::VERIFY_PEER }
      }
    elsif encryption == :simple_tls
      connection_params[:encryption] = {
        method: :simple_tls,
        tls_options: { verify_mode: OpenSSL::SSL::VERIFY_PEER }
      }
    end

    # Configure authentication
    if username && password
      # Use custom bind_dn if provided (for service accounts), otherwise build standard DN
      auth_bind_dn = bind_dn || "uid=#{username},ou=People,#{base}"
      connection_params[:auth] = {
        method: :simple,
        username: auth_bind_dn,
        password: password
      }
    else
      raise "LDAP authentication required: username and password must be configured"
    end

    Net::LDAP.new(connection_params)
  end

  def self.get_user_attribute(uniqname, attribute, default_value = nil)
    ldap = ldap_connection
    search_param = uniqname
    result_attrs = [attribute]

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      value = item[attribute]&.first
      return value unless value.nil?
    end

    default_value
  ensure
    get_ldap_response(ldap)
  end

  def self.get_nested_attribute(uniqname, nested_attribute)
    ldap = ldap_connection
    search_param = uniqname
    # Specify the full nested attribute path using dot notation
    attr_name = nested_attribute.split('.').first
    # Try using the configured attribute name if available, otherwise use the provided name
    search_attr = dept_attribute || attr_name
    result_attrs = [search_attr]
  
    search_filter = Net::LDAP::Filter.eq('uid', search_param)
  
    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      # Net::LDAP::Entry provides case-insensitive access, try the search attribute first
      string1 = item[search_attr]&.first || item[attr_name]&.first
      if string1
        key_value_pairs = string1.split('}:{')
        # Find the key-value pair for the nested attribute
        target_pair = key_value_pairs.find { |pair| pair.include?("#{nested_attribute.split('.').last}=") } 
        # Extract the target value
        if target_pair
          target_pair_value = target_pair.split('=').last
          return target_pair_value unless target_pair_value.nil?
        end
      end
    end
    nil

  ensure
    get_ldap_response(ldap)
  end

  # method to check if a uid exist in LDAP
  def self.uid_exist?(uniqname)
    ldap = ldap_connection
    search_param = uniqname

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    ldap.search(filter: search_filter) do |item|
      return true if item['uid'].first == search_param
    end

    false
  ensure
    get_ldap_response(ldap)
  end

  def self.get_simple_name(uniqname)
    get_user_attribute(uniqname, 'displayname', 'not available')
  end

  def self.get_email(uniqname)
    get_user_attribute(uniqname, 'mail', nil)
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

    found = false
    ldap.search(filter: search_filter, attributes: result_attrs) do |item|
      members = item['member']
      if members && members.any? { |entry| entry.split(',').first.split('=')[1] == uid }
        found = true
      end
    end

    found
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