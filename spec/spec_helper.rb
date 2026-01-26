require 'bundler/setup'
require 'ldap_lookup'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure LDAP settings for tests
  # Credentials should be provided via environment variables for security
  # Example: LDAP_USERNAME=your_uniqname LDAP_PASSWORD=your_password bundle exec rspec
  config.before(:suite) do
    username = ENV['LDAP_USERNAME']
    password = ENV['LDAP_PASSWORD']
    
    if username.nil? || password.nil?
      warn "WARNING: LDAP_USERNAME and LDAP_PASSWORD environment variables not set."
      warn "Tests will use default values which may not work for authenticated LDAP connections."
      warn "Set them with: export LDAP_USERNAME=your_uniqname && export LDAP_PASSWORD=your_password"
    end

    LdapLookup.configuration do |config|
      config.host = ENV['LDAP_HOST'] || "ldap.umich.edu"
      config.port = ENV['LDAP_PORT'] || "389"
      config.base = ENV['LDAP_BASE'] || "dc=umich,dc=edu"
      config.username = username || "rsmoke"
      config.password = password || "test_password"
      config.encryption = (ENV['LDAP_ENCRYPTION'] || "start_tls").to_sym
      config.dept_attribute = "umichPostalAddressData"
      config.group_attribute = "umichGroupEmail"
    end
  end

  # Reset configuration between tests to avoid state leakage
  config.after(:each) do
    # Configuration is class-level, so we don't need to reset unless testing config changes
  end
end
