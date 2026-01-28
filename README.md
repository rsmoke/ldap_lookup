# LdapLookup for Ruby [![Gem Version](https://badge.fury.io/rb/ldap_lookup.svg)](https://badge.fury.io/rb/ldap_lookup)

## Overview

LdapLookup provides authenticated or anonymous lookups of user attributes in the University of Michigan MCommunity LDAP service. It supports encrypted binds per UM IT Security (effective Jan 20, 2026) and can be adapted for other LDAP servers.

### UM LDAP Requirements (as of Jan 20, 2026)

* **Authenticated binds only** - UM LDAP does not allow anonymous binds.
* Username and password are required for UM LDAP.
* Encrypted connections (STARTTLS or LDAPS) are mandatory.
* The gem uses LDAP "simple bind" authentication (authenticated with username/password).

The gem can also perform **anonymous binds** for LDAP servers that allow them. To use anonymous binds, leave `LDAP_USERNAME` and `LDAP_PASSWORD` unset.

## Quick Start (Local Test Runner)

### Requirements

* Ruby at least 2.0.0
* Gem `net-ldap` ~> `0.18.0`

> The Net::LDAP (aka net-ldap) gem before 0.16.0 for Ruby has a missing SSL certificate validation.

1. Clone the repo.
2. Copy the env template: `cp .env.example .env`.
3. Load the env vars into your shell:

   ```bash
   set -a
   source .env
   set +a
   ```

4. Edit the configuration in `ldaptest.rb` (reads from `.env`):

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
     config.debug = debug_str ? debug_str.to_s.downcase == 'true' : false
   end
   ```

5. Run the test script:

   ```bash
   ruby ./ldaptest.rb
   ```

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

Request a **service account** from your IT department. Service accounts are designed for automated applications and do not require password changes.

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
  # Note: LDAP_BIND_DN replaces LDAP_USERNAME, not LDAP_PASSWORD.

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
* Security note: debug output can include identifiers (uids, group names, search filters). Avoid sharing logs publicly.

## Environment Variables

**Never hardcode credentials in your code.** Use environment variables (Hatchbox, Heroku, etc.).

### Development with `.env.example` (Recommended)

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

### Production (Hatchbox)

Hatchbox uses environment variables per app or per deployment. Configure these in
**Hatchbox > App > Environment Variables** (or your deployment pipeline), then redeploy or restart.

**Minimum required for authenticated UM LDAP:**

```bash
LDAP_USERNAME=service_account_uniqname
LDAP_PASSWORD=service_account_password
LDAP_ENCRYPTION=start_tls
LDAP_HOST=ldap.umich.edu
LDAP_PORT=389
LDAP_BASE=dc=umich,dc=edu
```

**Recommended for service accounts with a custom bind DN:**

```bash
LDAP_BIND_DN=cn=service-account,ou=Applications,o=services
```

**Optional tuning:**

```bash
LDAP_TLS_VERIFY=true
LDAP_CA_CERT=/path/to/ca-bundle.pem
LDAP_USER_BASE=ou=people,dc=umich,dc=edu
LDAP_GROUP_BASE=ou=user groups,ou=groups,dc=umich,dc=edu
LDAP_DEPT_ATTRIBUTE=umichPostalAddressData
LDAP_GROUP_ATTRIBUTE=umichGroupEmail
LDAP_DIAGNOSTIC_UID=your_uniqname
```

### Alternative: Export in Your Shell

```bash
export LDAP_USERNAME=your_service_account_uniqname
export LDAP_PASSWORD=your_service_account_password
```

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

**get_simple_name** returns the display name or `"not available"`.

```ruby
LdapLookup.get_simple_name(uniqname = nil)
response: name or "not available"
```

**get_dept** returns the user's department name or `nil`.

```ruby
LdapLookup.get_dept(uniqname = nil)
response: dept name or nil
```

**get_email** returns the user's email address or `nil`.

```ruby
LdapLookup.get_email(uniqname = nil)
response: email or nil
```

**is_member_of_group?** returns true/false if uniqname is a member of the specified group.

```ruby
LdapLookup.is_member_of_group?(uid = nil, group_name = nil)
response: true or false (boolean)
```

**get_email_distribution_list** returns a hash with group data or an empty hash.

```ruby
LdapLookup.get_email_distribution_list(group_name = nil)
response: result_hash
```

**all_groups_for_user** returns the list of groups that a user is a member of.

```ruby
LdapLookup.all_groups_for_user(uniqname = nil)
response: result_array
```

## Troubleshooting

### Auth failures

* UM LDAP requires authenticated binds. Ensure `LDAP_USERNAME` and `LDAP_PASSWORD` are set.
* For service accounts, set `LDAP_BIND_DN` to the DN provided by your IT team.
* Confirm the account is enabled for LDAP and the password is current.

### TLS/SSL errors

* Use `LDAP_ENCRYPTION=start_tls` with port `389`, or `simple_tls` with port `636`.
* If certificate validation fails, set `LDAP_CA_CERT` to a CA bundle path.
* Avoid `LDAP_TLS_VERIFY=false` outside local testing.

### Bind DN tips

* Default bind DN is `uid=username,ou=People,base`.
* Service accounts often require a custom DN; set `LDAP_BIND_DN` accordingly.

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
# DON'T: Password visible in process list
LDAP_PASSWORD=xxx bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [rsmoke/ldap_lookup](https://github.com/rsmoke/ldap_lookup). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](https://www.contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rsmoke/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
