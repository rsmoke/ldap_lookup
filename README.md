# LdapLookup for Ruby [![Gem Version](https://badge.fury.io/rb/ldap_lookup.svg)](https://badge.fury.io/rb/ldap_lookup)

### Description
This module is to be used for anonymous lookup of user attributes in the MCommunity service provide at the University of Michigan. It can be easily modifed to use other LDAP server configurations.

---

### Try it out

Requirements:
* Ruby at least 2.0.0
* Gem 'net-ldap' ~> '0.16.1'
> *The Net::LDAP (aka net-ldap) gem before 0.16.0 for Ruby has a Missing SSL Certificate Validation.*

To try the module out:
1. Clone the repo
2. Edit the configurations by opening ldaptest.rb and set the *CONFIGURATION BLOCK* to your environment.
<pre>
LdapLookup.configuration do |config|
      config.host = <em>< your host ></em> # "ldap.umich.edu"
      config.port = <em>< your port ></em> # "986" the default is set to "389" so this optional
      config.base = <em>< your LDAP base ></em> # "dc=umich,dc=edu"
      config.dept_attribute = <em>< your dept attribute ></em> # "umichPostalAddressData"
      config.group_attribute = <em>< your group email attribute ></em> # "umichGroupEmail"
end
</pre>

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
    config.port = <em>< your port ></em> # "954" port 389 is set by default
    config.base = <em>< your LDAP base ></em> # "dc=umich,dc=edu"
    config.dept_attribute = <em>< your dept attribute ></em> # "umichPostalAddressData"
    config.group_attribute = <em>< your group email attribute ></em> # "umichGroupEmail"
end
</pre>

---

### Methods available

__get_simple_name:__ returns the Display Name
```
LdapLookup.get_simple_name(uniqname = nil)
```
__get_dept:__ returns the users Department_name
```
LdapLookup.get_dept(uniqname = nil)
```
__get_email:__ returns the users email address
```
LdapLookup.get_email(uniqname = nil)
```
__is_member_of_group?:__ returns true/false if uniqname is a member of the specified group
```
LdapLookup.is_member_of_group?(uid = nil, group_name = nil)
```
__get_email_distribution_list:__ Returns the list of emails that are associated to a group.
```
LdapLookup.get_email_distribution_list(group_name = nil)
```
__all_groups_for_user: Returns the list of groups that a user is a member of.
```
LdapLookup.all_groups_for_user(uniqname = nil)
```

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rsmoke/ldap_lookup. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
