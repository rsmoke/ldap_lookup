# Quick Setup Guide for Gem Users

This guide helps you set up `ldap_lookup` in a Rails app.

## Overview

LdapLookup provides authenticated or anonymous lookups of user attributes in the University of Michigan MCommunity LDAP service. It supports encrypted binds per UM IT Security (effective Jan 28, 2026) and can be adapted for other LDAP servers.

### UM LDAP Requirements (as of Jan 28, 2026)

- **Authenticated binds only** - UM LDAP does not allow anonymous binds.
- Username and password are required for UM LDAP.
- Encrypted connections (STARTTLS or LDAPS) are mandatory.

## Installation

### 1. Add to Gemfile

```ruby
gem 'ldap_lookup'
```

Run `bundle install`.

### 2. Create Initializer

```bash
# If you have the gem source
cp config/initializers/ldap_lookup.rb.example config/initializers/ldap_lookup.rb

# Or create it manually
touch config/initializers/ldap_lookup.rb
```

### 3. Configure the Gem

Edit `config/initializers/ldap_lookup.rb`:

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
  # Note: LDAP_BIND_DN replaces LDAP_USERNAME (LDAP_USERNAME can be unset), not LDAP_PASSWORD.

  # Encryption - REQUIRED (defaults to STARTTLS)
  config.encryption = ENV.fetch('LDAP_ENCRYPTION', 'start_tls').to_sym
  # Use :simple_tls for LDAPS on port 636
  # TLS verification (defaults to true). Set LDAP_TLS_VERIFY=false only for local testing.
  # Optional custom CA bundle: set LDAP_CA_CERT=/path/to/ca-bundle.pem

  # Optional: Logger for debug output (responds to debug/info or call)
  # config.logger = Rails.logger
end
```

### Logger and Debug Output

- Debug logging is controlled by `config.debug` (default is false).
- If `config.logger` is set, it is used in this order:
  - `logger.debug(message)` if available.
  - `logger.info(message)` if `debug` is not available.
  - `logger.call(message)` if neither `debug` nor `info` are available.
- If no logger is configured, debug output goes to STDOUT.
- Security note: debug output can include identifiers (uids, group names, search filters). Avoid sharing logs publicly.

## Environment Variables

### Development (.env File)

```bash
LDAP_USERNAME=your_service_account
LDAP_PASSWORD=your_password
LDAP_BIND_DN=cn=service-account,ou=Applications,o=services
LDAP_DIAGNOSTIC_UID=your_uniqname
```

### Production (Hatchbox)

Configure these in **Hatchbox > App > Environment Variables**, then redeploy or restart.

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

### Service Account Bind DN (if needed)

If your service account uses a custom bind DN format, add:

```ruby
config.bind_dn = 'cn=service-account,ou=Applications,o=services'
```

Your IT department can provide the correct DN.

## Non-Rails Setup

If you are not using Rails, configure `LdapLookup.configuration` during app startup and provide the same environment variables. See the Non-Rails example in `README.md` for a full snippet.

## Usage

```ruby
# Check if a user exists
LdapLookup.uid_exist?('uniqname')

# Get user's name
LdapLookup.get_simple_name('uniqname')

# Get user's email
LdapLookup.get_email('uniqname')

# Get user's department
LdapLookup.get_dept('uniqname')

# Check group membership
LdapLookup.is_member_of_group?('uniqname', 'group-name')

# Get all groups for a user
LdapLookup.all_groups_for_user('uniqname')
```

## Troubleshooting

### Auth Failures

- UM LDAP requires authenticated binds. Ensure `LDAP_USERNAME` and `LDAP_PASSWORD` are set.
- For service accounts, set `LDAP_BIND_DN` to the DN provided by your IT team.
- Confirm the account is enabled for LDAP and the password is current.

### TLS/SSL Errors

- Use `LDAP_ENCRYPTION=start_tls` with port `389`, or `simple_tls` with port `636`.
- If certificate validation fails, set `LDAP_CA_CERT` to a CA bundle path.
- Avoid `LDAP_TLS_VERIFY=false` outside local testing.

### Bind DN Tips

- Default bind DN is `uid=username,ou=People,base`.
- Service accounts often require a custom DN; set `LDAP_BIND_DN` accordingly.

## Security Reminders

- Use environment variables for credentials.
- Use service accounts in production.
- Never commit credentials to version control.
- Don't hardcode passwords in code.
- Don't use personal accounts in production.
