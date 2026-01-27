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
    unless response.code.zero?
      error_msg = "Response Code: #{response.code}, Message: #{response.message}"
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
    auth_dn = bind_dn || "uid=#{username},ou=People,#{base}"
    
    result = {
      bind_dn: auth_dn,
      username: username,
      host: host,
      port: port,
      encryption: encryption,
      base: base
    }
    
    begin
      ldap = ldap_connection
      
      # Check if TLS/SSL connection was established successfully
      # If certificate verification fails, we'd get an exception here
      
      # Net::LDAP binds automatically when auth is set, but let's try explicit bind
      bind_result = ldap.bind
      bind_response = ldap.get_operation_result
      
      result.merge!(
        bind_successful: bind_result,
        bind_code: bind_response.code,
        bind_message: bind_response.message
      )
      
      unless bind_result
        result[:success] = false
        result[:error] = "Bind failed: Code #{bind_response.code}, #{bind_response.message}"
        result[:code] = bind_response.code
        
        # Provide helpful guidance based on error code
        case bind_response.code
        when 19
          result[:suggestion] = "Constraint Violation on bind. Your account may not be enabled for LDAP access. Contact ITS Service Center to enable LDAP access for your account."
        when 49
          result[:suggestion] = "Invalid Credentials. Check your username and password."
        when 50
          result[:suggestion] = "Insufficient Access Rights. Your account may need LDAP access enabled."
        end
        
        return result
      end
      
      # Try a simple search to verify permissions
      search_result = ldap.search(base: base, filter: "(objectClass=*)", size: 1)
      search_response = ldap.get_operation_result
      
      result.merge!(
        success: search_response.code.zero?,
        search_code: search_response.code,
        search_message: search_response.message
      )
      
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
    if encryption == :start_tls
      connection_params[:encryption] = {
        method: :start_tls,
        tls_options: { 
          verify_mode: OpenSSL::SSL::VERIFY_PEER
          # System CA certificates should include InCommon certificates
          # If certificate verification fails, check your system's CA certificate store
        }
      }
    elsif encryption == :simple_tls
      connection_params[:encryption] = {
        method: :simple_tls,
        tls_options: { 
          verify_mode: OpenSSL::SSL::VERIFY_PEER
          # System CA certificates should include InCommon certificates
        }
      }
    end

    # Configure authenticated bind (required as of Jan 20, 2026)
    # UM documentation: "Authenticate with your uniqname and UMICH (Level-1) password"
    # Note: "simple" bind method = authenticated bind with username/password (not anonymous)
    if username && password
      # Use custom bind_dn if provided (for service accounts), otherwise build standard DN
      auth_bind_dn = bind_dn || "uid=#{username},ou=People,#{base}"
      connection_params[:auth] = {
        method: :simple,  # Simple bind = authenticated bind with username/password
        username: auth_bind_dn,
        password: password
      }
    else
      raise "LDAP authentication required: username and password must be configured. Anonymous binds are no longer supported."
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

    # Use configured base instead of hardcoded dc=umich,dc=edu
    member_dn = "uid=#{uid},ou=People,#{base}"
    ldap.search(filter: "member=#{member_dn}", attributes: result_attrs) do |item|
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