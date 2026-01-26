# LdapLookup for Ruby [![Gem Version](https://badge.fury.io/rb/ldap_lookup.svg)](https://badge.fury.io/rb/ldap_lookup)

### Description
This module is to be used for authenticated lookup of user attributes in the MCommunity service provided at the University of Michigan. It requires authenticated LDAP binds with encryption as per UM IT Security requirements (effective Jan 28, 2026). It can be easily modified to use other LDAP server configurations.

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

**Important:** As of January 28, 2026, UM LDAP requires:
- Authenticated binds (username and password are required)
- Encrypted connections (STARTTLS or LDAPS)

3. run the ldaptest.rb script
```ruby
ruby ./ldaptest.rb
```

---

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'ldap_lookup'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ldap_lookup

In your application create a file config/initializers/ldap_lookup.rb
<pre>
LdapLookup.configuration do |config|
    config.host = <em>< your host ></em> # "ldap.umich.edu"
    config.port = <em>< your port ></em> # "389" (default) for STARTTLS, "636" for LDAPS
    config.base = <em>< your LDAP base ></em> # "dc=umich,dc=edu"
    config.username = <em>< your uniqname ></em> # Your UM uniqname
    config.password = <em>< your password ></em> # Your UM password (consider using ENV vars)
    config.encryption = :start_tls  # :start_tls (default) or :simple_tls for LDAPS
    config.dept_attribute = <em>< your dept attribute ></em> # "umichPostalAddressData"
    config.group_attribute = <em>< your group email attribute ></em> # "umichGroupEmail"
end
</pre>

**Security Note:** For production applications, store credentials in environment variables:
<pre>
config.username = ENV['LDAP_USERNAME']
config.password = ENV['LDAP_PASSWORD']
</pre>

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

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rsmoke/ldap_lookup. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
