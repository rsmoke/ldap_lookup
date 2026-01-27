# Quick Setup Guide for Gem Users

This guide will help you quickly set up `ldap_lookup` in your Rails application.

## Prerequisites

1. **Get LDAP Credentials**
   - For production: Request a service account from your IT department
   - For development: You can temporarily use your personal uniqname/password

## Installation Steps

### 1. Add to Gemfile

```ruby
gem 'ldap_lookup'
```

Run `bundle install`

### 2. Create Initializer

Copy the example initializer:

```bash
# If you have the gem source
cp config/initializers/ldap_lookup.rb.example config/initializers/ldap_lookup.rb

# Or create it manually
touch config/initializers/ldap_lookup.rb
```

### 3. Configure Credentials

Edit `config/initializers/ldap_lookup.rb`:

```ruby
LdapLookup.configuration do |config|
  config.host = ENV.fetch('LDAP_HOST', 'ldap.umich.edu')
  config.base = ENV.fetch('LDAP_BASE', 'dc=umich,dc=edu')
  # Leave unset to use anonymous binds (if your LDAP server allows it)
  config.username = ENV['LDAP_USERNAME']
  config.password = ENV['LDAP_PASSWORD']
  config.encryption = :start_tls
end
```

### 4. Set Environment Variables

**Development (.env file):**
```bash
LDAP_USERNAME=your_service_account
LDAP_PASSWORD=your_password
```

**Production:**
Use your platform's secrets management:
- Rails: `config/credentials.yml.enc`
- Heroku: `heroku config:set LDAP_USERNAME=xxx`
- AWS: Secrets Manager
- etc.

### 5. Service Account Bind DN (if needed)

If your service account uses a custom bind DN format, add:

```ruby
config.bind_dn = 'cn=service-account,ou=Service Accounts,dc=umich,dc=edu'
```

Your IT department will provide this if it's different from the default format.

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

**Anonymous bind fails**
- Your LDAP server may require authenticated binds
- Set `LDAP_USERNAME` and `LDAP_PASSWORD` (service account recommended)
- Verify credentials are correct

**Error: Connection timeout or SSL errors**
- Verify `config.host` is correct
- Try `config.encryption = :simple_tls` with `config.port = '636'` for LDAPS
- Check firewall rules allow outbound LDAP connections

**Service account not working**
- Verify the bind DN format with your IT department
- Set `config.bind_dn` if your service account uses a non-standard format

## Security Reminders

- ✅ Use environment variables for credentials
- ✅ Use service accounts in production
- ✅ Never commit credentials to version control
- ❌ Don't hardcode passwords in code
- ❌ Don't use personal accounts in production
