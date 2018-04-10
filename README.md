# LdapLookup for Ruby

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/ldap_lookup`. To experiment with that code, run `bin/console` for an interactive prompt.

### Description
This module is to be used for anonymous lookup of user attributes in the MCommunity service provide at the University of Michigan. It can be easily modifed to use other LDAP server configurations.

## Try it out
To try the module out you may clone the repo and run the ldaptest.rb script
```ruby
ruby ./ldaptest.rb
```
Requirements:
* Ruby at least 2.0.0
* Gem 'net-ldap' ~> '0.16.1'
> Install by running the following command at your command prompt_for_action
>
> *The Net::LDAP (aka net-ldap) gem before 0.16.0 for Ruby has a Missing SSL Certificate Validation.*
```bash
gem install net-ldap
```

* Time to try it out

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'ldap_lookup'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ldap_lookup

### Usage

TODO: Write usage instructions here

### Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rsmoke/ldap_lookup. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

### Code of Conduct

Everyone interacting in the LdapLookup project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ldap_lookup/blob/master/CODE_OF_CONDUCT.md).
