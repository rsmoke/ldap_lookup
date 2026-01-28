# LdapLookup for Ruby [![Gem Version](https://badge.fury.io/rb/ldap_lookup.svg)](https://badge.fury.io/rb/ldap_lookup)

## Description

This module is to be used for authenticated or anonymous lookup of user attributes in the MCommunity service provided at the University of Michigan. It supports authenticated LDAP binds with encryption as per UM IT Security requirements (effective Jan 20, 2026). It can be easily modified to use other LDAP server configurations.

## Try It Out

### Requirements

* Ruby at least 2.0.0
* Gem `net-ldap` ~> `0.18.0`

> The Net::LDAP (aka net-ldap) gem before 0.16.0 for Ruby has a missing SSL certificate validation.

### Quick Start

1. Clone the repo.
2. Copy the env template and set credentials: `cp .env.example .env`.
3. Load the env vars into your shell (example):

   ```bash
   set -a
   source .env
   set +a
   ```

4. Edit the configurations by opening `ldaptest.rb` and set the CONFIGURATION BLOCK to your environment (it reads from the `.env` values you just loaded).

   ```ruby
   LdapLookup.configuration do |config|
     config.host = ENV['LDAP_HOST'] || "ldap.umich.edu"
     config.port = ENV['LDAP_PORT'] || "389"
     config.base = ENV['LDAP_BASE'] || "dc=umich,dc=edu"
     # Leave username/password unset for anonymous binds
     config.username = ENV['LDAP_USERNAME']
     config.password = ENV['LDAP_PASSWORD']
     # Service account bind DN (preferred for UM LDAP)
     config.bind_dn = ENV['LDAP_BIND_DN']
     # Read encryption from ENV, default to start_tls
     encryption_str = ENV['LDAP_ENCRYPTION'] || 'start_tls'
     config.encryption = encryption_str.to_sym
     config.dept_attribute = ENV['LDAP_DEPT_ATTRIBUTE'] || "umichPostalAddressData"
     config.group_attribute = ENV['LDAP_GROUP_ATTRIBUTE'] || "umichGroupEmail"
     # Optional diagnostic UID (used by LdapLookup.test_connection)
     config.diagnostic_uid = ENV['LDAP_DIAGNOSTIC_UID'] if ENV['LDAP_DIAGNOSTIC_UID']
     # Optional search bases for UM LDAP
     config.user_base = ENV['LDAP_USER_BASE'] if ENV['LDAP_USER_BASE']
     config.group_base = ENV['LDAP_GROUP_BASE'] if ENV['LDAP_GROUP_BASE']
     # Enable LDAP debug logging in this test runner
     debug_str = ENV['LDAP_DEBUG']
     config.debug = debug_str ? debug_str.to_s.downcase == 'true' : true
   end
   ```

5. Run the `ldaptest.rb` script:

   ```bash
   ruby ./ldaptest.rb
   ```

### UM LDAP Requirements (as of Jan 20, 2026)

* **Authenticated binds only** - Anonymous (unauthenticated) binds are not supported by UM LDAP.
* Username and password are required for UM LDAP connections.
* Encrypted connections (STARTTLS or LDAPS) are mandatory.
* The gem uses LDAP "simple bind" authentication (authenticated with username/password).

The gem can also perform **anonymous binds** for LDAP servers that allow them. To use anonymous binds, leave `LDAP_USERNAME` and `LDAP_PASSWORD` unset.

## Installation

### Step 1: Add to Gemfile

Add this line to your application's Gemfile:

```ruby
gem 'ldap_lookup'
```

Then run:

```bash
bundle install
```

### Step 2: Get LDAP Credentials

**For Production Applications (Recommended):**

Request a **service account** from your IT department. Service accounts are designed for automated applications and don't require password changes.

**For Development/Testing:**

You can use your personal UM uniqname and password temporarily, but switch to a service account for production.

### Step 3: Configure the Gem

**For Rails Applications:**

Create `config/initializers/ldap_lookup.rb`:

```ruby
LdapLookup.configuration do |config|
  # Server Configuration (defaults work for UM LDAP)
  config.host = ENV.fetch('LDAP_HOST', 'ldap.umich.edu')
  config.port = ENV.fetch('LDAP_PORT', '389')
  config.base = ENV.fetch('LDAP_BASE', 'dc=umich,dc=edu')

  # Authentication (optional for anonymous binds)
  # Leave unset to use anonymous binds (if your LDAP server allows it)
  config.username = ENV['LDAP_USERNAME']
  config.password = ENV['LDAP_PASSWORD']

  # If using a service account with custom bind DN, uncomment and set:
  # config.bind_dn = ENV['LDAP_BIND_DN']

  # Encryption - REQUIRED (defaults to STARTTLS)
  config.encryption = ENV.fetch('LDAP_ENCRYPTION', 'start_tls').to_sym
  # Use :simple_tls for LDAPS on port 636
  # TLS verification (defaults to true). Set LDAP_TLS_VERIFY=false only for local testing.
  # Optional custom CA bundle: set LDAP_CA_CERT=/path/to/ca-bundle.pem

  # Optional: Attribute Configuration
  config.dept_attribute = ENV.fetch('LDAP_DEPT_ATTRIBUTE', 'umichPostalAddressData')
  config.group_attribute = ENV.fetch('LDAP_GROUP_ATTRIBUTE', 'umichGroupEmail')

  # Optional: Logger for debug output (responds to debug/info or call)
  # config.logger = Rails.logger

  # Optional: Separate search bases for users and groups (UM service accounts)
  # config.user_base = ENV.fetch('LDAP_USER_BASE', 'ou=people,dc=umich,dc=edu')
  # config.group_base = ENV.fetch('LDAP_GROUP_BASE', 'ou=user groups,ou=groups,dc=umich,dc=edu')
end
```

**For Non-Rails Applications:**

Configure in your application startup:

```ruby
require 'ldap_lookup'
require 'logger'

LdapLookup.configuration do |config|
  config.host = 'ldap.umich.edu'
  config.base = 'dc=umich,dc=edu'
  config.username = ENV['LDAP_USERNAME']
  config.password = ENV['LDAP_PASSWORD']
  config.encryption = :start_tls
  # Optional: Logger for debug output
  # config.logger = Logger.new($stdout)
end
```

### Logger and Debug Output

* Debug logging is controlled by `config.debug` (default is false).
* If `config.logger` is set, it is used in this order:
  * `logger.debug(message)` if available.
  * `logger.info(message)` if `debug` is not available.
  * `logger.call(message)` if neither `debug` nor `info` are available.
* If no logger is configured, debug output goes to STDOUT.

### Step 4: Set Environment Variables

**Never hardcode credentials in your code!** Use environment variables (Hatchbox, Heroku, etc.).

**Development with `.env.example` (recommended):**

1. Copy the template: `cp .env.example .env`
2. Update the values in `.env` for your environment.
3. Load the variables into your shell (example):

   ```bash
   set -a
   source .env
   set +a
   ```

**Typical `.env` values:**

```bash
LDAP_USERNAME=your_service_account_uniqname
LDAP_PASSWORD=your_service_account_password
LDAP_BIND_DN=cn=service-account,ou=Applications,o=services
```

**Optional settings (override defaults as needed):**

```bash
LDAP_HOST=ldap.umich.edu
LDAP_PORT=389
LDAP_BASE=dc=umich,dc=edu
LDAP_ENCRYPTION=start_tls
LDAP_TLS_VERIFY=true
LDAP_CA_CERT=/path/to/ca-bundle.pem
LDAP_DEPT_ATTRIBUTE=umichPostalAddressData
LDAP_GROUP_ATTRIBUTE=umichGroupEmail
LDAP_DIAGNOSTIC_UID=your_uniqname
LDAP_USER_BASE=ou=people,dc=umich,dc=edu
LDAP_GROUP_BASE=ou=user groups,ou=groups,dc=umich,dc=edu
```

#### Alternative: Export in your shell

```bash
export LDAP_USERNAME=your_service_account_uniqname
export LDAP_PASSWORD=your_service_account_password
```

#### For Production

* Use your platform's secrets management (Rails credentials, AWS Secrets Manager, etc.).
* Never commit credentials to version control.
* Use service accounts, not personal accounts.

### Service Account Bind DN

If your service account uses a non-standard bind DN format, you can specify it:

```ruby
config.bind_dn = 'cn=my-service-account,ou=Applications,o=services'
```

If `bind_dn` is not set, it defaults to: `uid=username,ou=People,base`.

## Methods Available

**uid_exist?** returns true if uid is in LDAP.

```ruby
LdapLookup.uid_exist?(uniqname)
response: true or false (boolean)
```

**get_simple_name** returns the display name.

```ruby
LdapLookup.get_simple_name(uniqname = nil)
response: name or "No #{attribute} found for #{uniqname}"
```

**get_dept** returns the user's department name.

```ruby
LdapLookup.get_dept(uniqname = nil)
response: dept name or "No #{nested_attribute} found for #{uniqname}"
```

**get_email** returns the user's email address.

```ruby
LdapLookup.get_email(uniqname = nil)
response: email or "No #{attribute} found for #{uniqname}"
```

**is_member_of_group?** returns true/false if uniqname is a member of the specified group.

```ruby
LdapLookup.is_member_of_group?(uid = nil, group_name = nil)
response: true or false (boolean)
```

**get_email_distribution_list** returns the list of emails that are associated to a group.

```ruby
LdapLookup.get_email_distribution_list(group_name = nil)
response: result_hash
```

**all_groups_for_user** returns the list of groups that a user is a member of.

```ruby
LdapLookup.all_groups_for_user(uniqname = nil)
response: result_array
```

## Running Tests

**Security Note:** Never put passwords in command line arguments. They are visible in process lists and shell history.

### Recommended: Use a .env file (most secure)

1. Copy the example file: `cp .env.example .env`
2. Edit `.env` with your credentials:

   ```bash
   LDAP_USERNAME=your_uniqname
   LDAP_PASSWORD=your_password
   ```

3. Run tests: `bundle exec rspec`

### Alternative: Export environment variables

```bash
export LDAP_USERNAME=your_uniqname
export LDAP_PASSWORD=your_password
bundle exec rspec
```

### Never do this (insecure)

```bash
# ❌ DON'T: Password visible in process list
LDAP_PASSWORD=xxx bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [rsmoke/ldap_lookup](https://github.com/rsmoke/ldap_lookup). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
