require 'ldap_lookup'

RSpec.describe LdapLookup do

  xit 'sets the host configuration' do
    expect(LdapLookup.configuration.host).to eql('ldap.umich,.edu')
  end

  xit 'creates a connection' do
    expect(LdapLookup.ldap_connection).to be_truthy
  end

  xit 'checks that search parameters are valid' do
    expect(LdapLookup.get_simple_name(:uniqname)).to eql('barba')
  end
end
