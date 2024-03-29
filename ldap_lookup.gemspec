
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ldap_lookup/version"

Gem::Specification.new do |spec|
  spec.name          = "ldap_lookup"
  spec.version       = LdapLookup::VERSION
  spec.authors       = ["Rick Smoke"]
  spec.email         = ["rsmoke@umich.edu"]

  spec.summary       = %q{For anonymous lookup of user LDAP attributes.}
  spec.description   = %q{This module is to be used for anonymous lookup of attributes in the MCommunity service provide at the University of Michigan. It can be easily modifed to use other LDAP server configurations.}
  spec.homepage      = "https://github.com/rsmoke/ldap_lookup.git"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.2.26"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.7.0"
  spec.add_dependency 'net-ldap', '~> 0.18.0'
end
