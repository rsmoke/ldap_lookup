# LdapLookup for Ruby [![Gem Version](https://badge.fury.io/rb/ldap_lookup.svg)](https://badge.fury.io/rb/ldap_lookup)

### Description
This module is to be used for authenticated or anonymous lookup of user attributes in the MCommunity service provided at the University of Michigan. It supports authenticated LDAP binds with encryption as per UM IT Security requirements (effective Jan 20, 2026). It can be easily modified to use other LDAP server configurations.

---

### Try it out

Requirements:
* Ruby at least 2.0.0
* Gem 'net-ldap' ~> '0.17.0'
> *The Net::LDAP (aka net-ldap) gem before 0.16.0 for Ruby has a Missing SSL Certificate Validation.*

To try the module out:
1. Clone the repo
2. Edit the configurations by opening ldaptest.rb and set the *CONFIGURATION BLOCK* to your environment.
<pre>
LdapLookup.configuration do |config|
      config.host = <em>< your host ></em> # "ldap.umich.edu"
      config.port = <em>< your port ></em> # "389" (default) for STARTTLS, "636" for LDAPS
      config.base = <em>< your LDAP base ></em> # "dc=umich,dc=edu"
      config.username = <em>< your uniqname ></em> # Your UM uniqname (e.g., "rsmoke")
      config.password = <em>< your password ></em> # Your UM password
      config.encryption = :start_tls  # :start_tls (default, port 389) or :simple_tls (LDAPS, port 636)
      config.dept_attribute = <em>< your dept attribute ></em> # "umichPostalAddressData"
      config.group_attribute = <em>< your group email attribute ></em> # "umichGroupEmail"
end
</pre>

**Important:** As of January 20, 2026, UM LDAP requires:
- **Authenticated binds only** - Anonymous (unauthenticated) binds are not supported by UM LDAP
- Username and password are required for UM LDAP connections
- Encrypted connections (STARTTLS or LDAPS) are mandatory
- The gem uses LDAP "simple bind" authentication (authenticated with username/password)

The gem can also perform **anonymous binds** for LDAP servers that allow them. To use anonymous binds, leave `LDAP_USERNAME` and `LDAP_PASSWORD` unset.

3. run the ldaptest.rb script
```ruby
ruby ./ldaptest.rb
```

---

### Installation

#### Step 1: Add to Gemfile

Add this line to your application's Gemfile:

```ruby
gem 'ldap_lookup'
```

Then run:

```bash
bundle install
```

#### Step 2: Get LDAP Credentials

**For Production Applications (Recommended):**
Request a **service account** from your IT department. Service accounts are designed for automated applications and don't require password changes.

**For Development/Testing:**
You can use your personal UM uniqname and password temporarily, but switch to a service account for production.

#### Step 3: Configure the Gem

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
  # config.bind_dn = 'cn=service-account,ou=Service Accounts,dc=umich,dc=edu'
  
  # Encryption - REQUIRED (defaults to STARTTLS)
  config.encryption = ENV.fetch('LDAP_ENCRYPTION', 'start_tls').to_sym
  # Use :simple_tls for LDAPS on port 636
  
  # Optional: Attribute Configuration
  config.dept_attribute = ENV.fetch('LDAP_DEPT_ATTRIBUTE', 'umichPostalAddressData')
  config.group_attribute = ENV.fetch('LDAP_GROUP_ATTRIBUTE', 'umichGroupEmail')
end
```

**For Non-Rails Applications:**

Configure in your application startup:

```ruby
require 'ldap_lookup'

LdapLookup.configuration do |config|
  config.host = 'ldap.umich.edu'
  config.base = 'dc=umich,dc=edu'
  config.username = ENV['LDAP_USERNAME']
  config.password = ENV['LDAP_PASSWORD']
  config.encryption = :start_tls
end
```

#### Step 4: Set Environment Variables

**Never hardcode credentials in your code!** Use environment variables (Hatchbox, Heroku, etc.):

```bash
# In your .env file (for development)
LDAP_USERNAME=your_service_account_uniqname
LDAP_PASSWORD=your_service_account_password

# Or export in your shell
export LDAP_USERNAME=your_service_account_uniqname
export LDAP_PASSWORD=your_service_account_password

# You can also set these (all can be changed without redeploying):
# LDAP_HOST, LDAP_PORT, LDAP_BASE, LDAP_ENCRYPTION
```

**For Production:**
- Use your platform's secrets management (Rails credentials, AWS Secrets Manager, etc.)
- Never commit credentials to version control
- Use service accounts, not personal accounts

#### Service Account Bind DN

If your service account uses a non-standard bind DN format, you can specify it:

```ruby
config.bind_dn = 'cn=my-service-account,ou=Service Accounts,dc=umich,dc=edu'
```

If `bind_dn` is not set, it defaults to: `uid=username,ou=People,base`

---

### Methods available

__uid_exist?:__ returns true if uid is in LDAP
```
LdapLookup.uid_exist?(uniqname)
response: true or false (boolean)
```
__get_simple_name:__ returns the Display Name
```
LdapLookup.get_simple_name(uniqname = nil)
response: name or "No #{attribute} found for #{uniqname}"
```
__get_dept:__ returns the users Department_name
```
LdapLookup.get_dept(uniqname = nil)
response: dept name or "No #{nested_attribute} found for #{uniqname}"
```
__get_email:__ returns the users email address
```
LdapLookup.get_email(uniqname = nil)
response: email or "No #{attribute} found for #{uniqname}"
```
__is_member_of_group?:__ returns true/false if uniqname is a member of the specified group
```
LdapLookup.is_member_of_group?(uid = nil, group_name = nil)
response: true or false (boolean)
```
__get_email_distribution_list:__ Returns the list of emails that are associated to a group.
```
LdapLookup.get_email_distribution_list(group_name = nil)
response: result_hash
```
__all_groups_for_user:__ Returns the list of groups that a user is a member of.
```
LdapLookup.all_groups_for_user(uniqname = nil)
response: result_array
```

### Running Tests

**Security Note:** Never put passwords in command line arguments. They are visible in process lists and shell history.

**Recommended: Use a .env file (most secure)**
1. Copy the example file: `cp .env.example .env`
2. Edit `.env` with your credentials:
   ```
   LDAP_USERNAME=your_uniqname
   LDAP_PASSWORD=your_password
   ```
3. Run tests: `bundle exec rspec`

**Alternative: Export environment variables**
```bash
export LDAP_USERNAME=your_uniqname
export LDAP_PASSWORD=your_password
bundle exec rspec
```

**Never do this (insecure):**
```bash
# ❌ DON'T: Password visible in process list
LDAP_PASSWORD=xxx bundle exec rspec
```

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rsmoke/ldap_lookup. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
