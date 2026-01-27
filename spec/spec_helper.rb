require 'bundler/setup'
require 'dotenv/load'  # Loads .env file if it exists
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
  # Credentials should be provided via .env file (see .env.example) or environment variables
  # NEVER commit your .env file or put passwords in command line arguments
  config.before(:suite) do
    username = ENV['LDAP_USERNAME']
    password = ENV['LDAP_PASSWORD']
    
    if username.nil? || password.nil?
      warn "\n" + "="*70
      warn "WARNING: LDAP_USERNAME and LDAP_PASSWORD not set."
      warn "Tests will attempt anonymous binds."
      warn "UM LDAP requires authenticated binds, so some tests may fail."
      warn ""
      warn "SECURE OPTIONS:"
      warn "  1. Create a .env file (recommended):"
      warn "     cp .env.example .env"
      warn "     # Then edit .env with your credentials"
      warn ""
      warn "  2. Set in your shell (export, not inline):"
      warn "     export LDAP_USERNAME=your_uniqname"
      warn "     export LDAP_PASSWORD=your_password"
      warn "     bundle exec rspec"
      warn ""
      warn "NEVER use: LDAP_PASSWORD=xxx bundle exec rspec (visible in process list!)"
      warn "="*70 + "\n"
    end

    LdapLookup.configuration do |config|
      config.host = ENV['LDAP_HOST'] || "ldap.umich.edu"
      config.port = ENV['LDAP_PORT'] || "389"
      config.base = ENV['LDAP_BASE'] || "dc=umich,dc=edu"
      config.username = username
      config.password = password
      config.encryption = (ENV['LDAP_ENCRYPTION'] || "start_tls").to_sym
      config.dept_attribute = ENV['LDAP_DEPT_ATTRIBUTE'] || "umichPostalAddressData"
      config.group_attribute = ENV['LDAP_GROUP_ATTRIBUTE'] || "umichGroupEmail"
    end
  end

  # Reset configuration between tests to avoid state leakage
  config.after(:each) do
    # Configuration is class-level, so we don't need to reset unless testing config changes
  end
end
