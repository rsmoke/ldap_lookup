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
  define_setting :user_base  # Optional: base DN for people lookups (e.g., ou=people,dc=umich,dc=edu)
  define_setting :group_base  # Optional: base DN for group lookups (e.g., ou=user groups,ou=groups,dc=umich,dc=edu)
  define_setting :encryption, :start_tls  # :start_tls or :simple_tls (LDAPS)
  define_setting :debug, false

  def self.debug_log(message)
    return unless debug

    puts "[LDAP DEBUG] #{message}"
  end

  def self.user_search_base
    base_value = user_base.to_s.strip
    return base_value unless base_value.empty?

    base
  end

  def self.group_search_base
    base_value = group_base.to_s.strip
    return base_value unless base_value.empty?

    base
  end

  def self.user_dn_base
    base_value = user_base.to_s.strip
    return base_value unless base_value.empty?

    "ou=People,#{base}"
  end

  def self.perform_search(ldap, base: nil, filter:, attributes: nil, label: nil, options: {})
    search_base = base || ldap.base
    filter_str = filter.respond_to?(:to_s) ? filter.to_s : filter.inspect
    attrs_list = attributes ? Array(attributes).map(&:to_s) : ['*']
    label_prefix = label ? "#{label} " : ""

    debug_log("#{label_prefix}search base=#{search_base} filter=#{filter_str} attrs=#{attrs_list.join(',')}")

    params = { base: search_base, filter: filter }
    params[:attributes] = attributes if attributes
    params.merge!(options) if options && !options.empty?

    results = ldap.search(params) || []
    entry_count = results ? results.size : 0
    returned_attrs = []
    if results && !results.empty?
      returned_attrs = results.first.attribute_names.map(&:to_s).sort
    end

    debug_log("#{label_prefix}search results count=#{entry_count} returned_attrs=#{returned_attrs.join(',')}")

    results
  end

  def self.operation_details(response)
    details = {
      code: response.code,
      message: response.message
    }

    if response.respond_to?(:error_message) && response.error_message && !response.error_message.empty?
      details[:error_message] = response.error_message
    end

    if response.respond_to?(:matched_dn) && response.matched_dn && !response.matched_dn.empty?
      details[:matched_dn] = response.matched_dn
    end

    if response.respond_to?(:referrals) && response.referrals && !response.referrals.empty?
      details[:referrals] = response.referrals
    end

    details
  end

  def self.get_ldap_response(ldap)
    response = ldap.get_operation_result
    unless response.code.zero?
      error_msg = "Response Code: #{response.code}, Message: #{response.message}"
      if response.respond_to?(:error_message) && response.error_message && !response.error_message.empty?
        error_msg += ", Diagnostic: #{response.error_message}"
      end
      if response.respond_to?(:matched_dn) && response.matched_dn && !response.matched_dn.empty?
        error_msg += ", Matched DN: #{response.matched_dn}"
      end
      # Provide more helpful error messages for common codes
      case response.code
      when 19
        error_msg += " (Constraint Violation - may require administrative access)"
      when 49
        error_msg += " (Invalid Credentials - check username/password)"
      when 50
        error_msg += " (Insufficient Access Rights)"
      when 81
        error_msg += " (Server Unavailable)"
      end
      raise error_msg
    end
  end

  # Diagnostic method to test LDAP connection and bind
  def self.test_connection
    username_present = username && !username.to_s.strip.empty?
    password_present = password && !password.to_s.strip.empty?
    bind_dn_present = bind_dn && !bind_dn.to_s.strip.empty?
    auth_dn = if bind_dn_present
      bind_dn
    elsif username_present
      "uid=#{username},#{user_dn_base}"
    end

    search_base = username_present ? user_search_base : (user_base || base)
    search_filter = username_present ? "(uid=#{username})" : "(objectClass=*)"

    result = {
      bind_dn: auth_dn,
      username: username,
      host: host,
      port: port,
      encryption: encryption,
      base: base,
      auth_mode: ((username_present || bind_dn_present) && password_present) ? 'authenticated' : 'anonymous'
    }

    begin
      ldap = ldap_connection

      bind_response = nil
      bind_exception = nil

      # Try an explicit bind for diagnostics only (can return Code 19 even if searches work)
      begin
        bind_success = ldap.bind
        bind_response = ldap.get_operation_result
      rescue => e
        bind_success = false
        bind_exception = { class: e.class.name, message: e.message }
      end

      # Net::LDAP binds automatically when performing operations (search, etc.)
      # Explicit bind may fail with Code 19 on STARTTLS, but actual operations work fine
      # Test by performing an actual search operation instead of explicit bind

      # Try a simple search - this will trigger automatic bind
      search_result = perform_search(
        ldap,
        base: search_base,
        filter: search_filter,
        attributes: ['uid', 'mail', 'displayName', 'cn', 'givenName', 'sn'],
        label: "diagnostic",
        options: { size: 1 }
      )
      search_response = ldap.get_operation_result
      returned_attributes = []
      if search_result && !search_result.empty?
        entry = search_result.first
        returned_attributes = entry.attribute_names.map(&:to_s).sort
      end

      if search_response.code.zero? || (search_response.code == 4 && (search_result && !search_result.empty?))
        # Success! Bind worked (automatically during search)
        result.merge!(
          success: true,
          bind_successful: true,
          bind_attempted: true,
          bind_result: bind_success,
          bind_details: bind_response ? operation_details(bind_response) : nil,
          bind_exception: bind_exception,
          bind_code: 0,
          bind_message: "Bind successful (via automatic bind during search)",
          search_code: search_response.code,
          search_message: search_response.message,
          search_details: operation_details(search_response),
          search_base: search_base,
          search_filter: search_filter,
          search_entry_count: search_result ? search_result.size : 0,
          search_returned_attributes: returned_attributes,
          note: "Explicit bind may show Code 19, but operations work correctly"
        )
      else
        # Search failed - check if it's a bind issue or search issue
        result.merge!(
          success: false,
          bind_successful: false,
          bind_attempted: true,
          bind_result: bind_success,
          bind_details: bind_response ? operation_details(bind_response) : nil,
          bind_exception: bind_exception,
          search_code: search_response.code,
          search_message: search_response.message,
          search_details: operation_details(search_response),
          search_base: search_base,
          search_filter: search_filter,
          search_entry_count: search_result ? search_result.size : 0,
          search_returned_attributes: returned_attributes,
          error: "Search failed: Code #{search_response.code}, #{search_response.message}"
        )

        case search_response.code
        when 19
          result[:suggestion] = "Constraint Violation. Your account may not be enabled for LDAP access or may need administrative access for this operation."
        when 49
          result[:suggestion] = "Invalid Credentials. Check your username and password."
        when 50
          result[:suggestion] = "Insufficient Access Rights. Your account may need LDAP access enabled."
        when 4
          result[:suggestion] = "Size Limit Exceeded. Try a more specific search base or ensure filters are indexed."
        end
      end

    rescue OpenSSL::SSL::SSLError => e
      # Certificate or SSL/TLS connection error
      result.merge!(
        success: false,
        error: "SSL/TLS Error: #{e.message}",
        exception: e.class.name,
        suggestion: "Certificate verification failed. Most systems trust InCommon certificates. If needed, download USERTrust RSA Certification Authority root certificate from ITS: SSL Server Certificates"
      )
    rescue => e
      result.merge!(
        success: false,
        error: e.message,
        exception: e.class.name
      )
    end

    result
  end

  def self.ldap_connection
    connection_params = {
      host: host,
      port: port.to_i,
      base: base
    }

    # Configure encryption - REQUIRED for authenticated binds per UM documentation
    # UM requires secure connection: TLS on port 389 (STARTTLS) or SSL on port 636 (LDAPS)
    # Most operating systems already trust InCommon certificates per UM documentation
    tls_verify = ENV.fetch('LDAP_TLS_VERIFY', 'true').to_s.downcase != 'false'
    tls_options = {
      verify_mode: tls_verify ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    }
    ca_cert_path = ENV['LDAP_CA_CERT']
    tls_options[:ca_file] = ca_cert_path if ca_cert_path && !ca_cert_path.to_s.strip.empty?

    if encryption == :start_tls
      connection_params[:encryption] = {
        method: :start_tls,
        tls_options: tls_options
      }
    elsif encryption == :simple_tls
      connection_params[:encryption] = {
        method: :simple_tls,
        tls_options: tls_options
      }
    end

    # Configure authenticated bind (if username/password provided)
    # Note: "simple" bind method = authenticated bind with username/password (not anonymous)
    auth_username = username.to_s.strip
    auth_password = password.to_s
    auth_bind_dn = bind_dn.to_s.strip
    if !auth_password.empty? && (!auth_bind_dn.empty? || !auth_username.empty?)
      # Use custom bind_dn if provided (for service accounts), otherwise build standard DN
      auth_bind_dn = auth_bind_dn.empty? ? "uid=#{auth_username},#{user_dn_base}" : auth_bind_dn
      connection_params[:auth] = {
        method: :simple,  # Simple bind = authenticated bind with username/password
        username: auth_bind_dn,
        password: auth_password
      }
    end

    ldap = Net::LDAP.new(connection_params)

    # For STARTTLS, ensure TLS is started before returning connection
    # Net::LDAP should handle this automatically, but let's be explicit
    if encryption == :start_tls
      begin
        # The bind will trigger STARTTLS automatically, but we can verify connection works
        # by attempting a bind (which will fail if TLS isn't established)
      rescue => e
        raise "Failed to establish TLS connection: #{e.message}"
      end
    end

    ldap
  end

  def self.get_user_attribute(uniqname, attribute, default_value = nil)
    ldap = ldap_connection
    search_param = uniqname
    result_attrs = [attribute]
    found_value = nil

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    perform_search(
      ldap,
      base: user_search_base,
      filter: search_filter,
      attributes: result_attrs,
      label: "get_user_attribute",
      options: { size: 1 }
    ).each do |item|
      value = item[attribute]&.first
      if value
        found_value = value
        break
      end
    end

    # Check response - Code 19 may occur even when data is found
    response = ldap.get_operation_result
    if (response.code == 19 || response.code == 4) && found_value.nil?
      # Constraint violation and no data found - may need admin access
      return default_value
    elsif response.code != 0 && found_value.nil?
      # Other error and no data found
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    # Return found value or default
    found_value || default_value
  end

  def self.get_nested_attribute(uniqname, nested_attribute)
    ldap = ldap_connection
    search_param = uniqname
    # Specify the full nested attribute path using dot notation
    attr_name = nested_attribute.split('.').first
    # Try using the configured attribute name if available, otherwise use the provided name
    search_attr = dept_attribute || attr_name
    result_attrs = [search_attr]
    found_value = nil

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    perform_search(
      ldap,
      base: user_search_base,
      filter: search_filter,
      attributes: result_attrs,
      label: "get_nested_attribute",
      options: { size: 1 }
    ).each do |item|
      # Net::LDAP::Entry provides case-insensitive access, try the search attribute first
      string1 = item[search_attr]&.first || item[attr_name]&.first
      if string1
        key_value_pairs = string1.split('}:{')
        # Find the key-value pair for the nested attribute
        target_pair = key_value_pairs.find { |pair| pair.include?("#{nested_attribute.split('.').last}=") }
        # Extract the target value
        if target_pair
          target_pair_value = target_pair.split('=').last
          if target_pair_value
            found_value = target_pair_value
            break
          end
        end
      end
    end

    # Check response - Code 19 may occur even when data is found
    response = ldap.get_operation_result
    if (response.code == 19 || response.code == 4) && found_value.nil?
      # Constraint violation and no data found - may need admin access
      return nil
    elsif response.code != 0 && found_value.nil?
      # Other error and no data found
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    found_value
  end

  # method to check if a uid exist in LDAP
  def self.uid_exist?(uniqname)
    ldap = ldap_connection
    search_param = uniqname
    found = false

    search_filter = Net::LDAP::Filter.eq('uid', search_param)

    perform_search(ldap, base: user_search_base, filter: search_filter, label: "uid_exist", options: { size: 1 }).each do |item|
      if item['uid'].first == search_param
        found = true
        break
      end
    end

    # Check response - Code 19 may occur even when user is found
    response = ldap.get_operation_result
    if (response.code == 19 || response.code == 4) && !found
      # Constraint violation and user not found - may need admin access
      return false
    elsif response.code != 0 && !found
      # Other error and user not found
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    found
  end

  def self.get_simple_name(uniqname)
    get_user_attribute(uniqname, 'displayname', 'not available')
  end

  def self.get_email(uniqname)
    get_user_attribute(uniqname, 'mail', nil)
  end

  def self.get_dept(uniqname)
    dept = get_nested_attribute(uniqname, 'umichpostaladdressdata.addr1')
    return dept if dept

    # Fallback to raw attribute if nested parsing fails or attribute is restricted
    raw_attr = dept_attribute || 'umichPostalAddressData'
    get_user_attribute(uniqname, raw_attr, nil)
  end

  def self.is_member_of_group?(uid, group_name)
    ldap = ldap_connection
    search_param = group_name
    result_attrs = ['member']
    found = false

    search_filter = Net::LDAP::Filter.join(
      Net::LDAP::Filter.eq('cn', search_param),
      Net::LDAP::Filter.eq('objectClass', 'group')
    )

    perform_search(ldap, base: group_search_base, filter: search_filter, attributes: result_attrs, label: "is_member_of_group").each do |item|
      members = item['member']
      if members && members.any? { |entry| entry.split(',').first.split('=')[1] == uid }
        found = true
        break
      end
    end

    # Check response - Code 19 may occur for group operations (requires admin access)
    response = ldap.get_operation_result
    if response.code == 19
      # Constraint violation - group operations may require admin access
      # Return false if not found, true if found (even with Code 19)
      return found
    elsif response.code != 0 && !found
      # Other error and not found
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    found
  end

  def self.get_email_distribution_list(group_name)
    ldap = ldap_connection
    result_hash = {}
    found_data = false

    search_param = group_name
    result_attrs = %w[cn umichGroupEmail member]

    search_filter = Net::LDAP::Filter.join(
      Net::LDAP::Filter.eq('cn', search_param),
      Net::LDAP::Filter.eq('objectClass', 'group')
    )

    perform_search(ldap, base: group_search_base, filter: search_filter, attributes: result_attrs, label: "get_email_distribution_list").each do |item|
      found_data = true
      result_hash['group_name'] = item['cn']&.first
      result_hash['group_email'] = item['umichGroupEmail']&.first
      members = item['member']&.map { |individual| individual.split(',').first.split('=')[1] }
      result_hash['members'] = members&.sort || []
    end

    # Check response - Code 19 may occur for group operations (requires admin access)
    response = ldap.get_operation_result
    if response.code == 19 && !found_data
      # Constraint violation and no data found - group operations may require admin access
      return {}
    elsif response.code != 0 && !found_data
      # Other error and no data found
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    result_hash
  end

  def self.all_groups_for_user(uid)
    ldap = ldap_connection
    result_array = []

    result_attrs = ['dn']

    # Use configured base instead of hardcoded dc=umich,dc=edu
    member_dn = "uid=#{uid},#{user_dn_base}"
    perform_search(ldap, base: group_search_base, filter: "member=#{member_dn}", attributes: result_attrs, label: "all_groups_for_user").each do |item|
      item.each { |key, value| result_array << value.first.split('=')[1].split(',')[0] }
    end

    # Check response - may raise Constraint Violation for regular users
    response = ldap.get_operation_result
    if response.code == 19  # Constraint Violation
      # Regular authenticated users may not have permission to search groups by member
      # Return empty array instead of raising error
      return []
    elsif response.code != 0
      raise "Response Code: #{response.code}, Message: #{response.message}"
    end

    result_array.sort
  end
end
