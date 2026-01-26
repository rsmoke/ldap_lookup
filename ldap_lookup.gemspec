
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ldap_lookup/version"

Gem::Specification.new do |spec|
  spec.name          = "ldap_lookup"
  spec.version       = LdapLookup::VERSION
  spec.authors       = ["Rick Smoke"]
  spec.email         = ["rsmoke@umich.edu"]

  spec.summary       = %q{Authenticated LDAP lookup for MCommunity user attributes at University of Michigan.}
  spec.description   = %q{This gem provides authenticated LDAP lookups for user attributes in the MCommunity service at the University of Michigan. It supports encrypted connections (STARTTLS/LDAPS) and service accounts as required by UM IT Security (effective Jan 28, 2026). Can be easily modified for other LDAP server configurations.}
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
  spec.add_development_dependency "dotenv", "~> 2.8"
  spec.add_dependency 'net-ldap', '~> 0.18.0'
end
