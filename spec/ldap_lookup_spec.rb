require 'ldap_lookup'

RSpec.describe LdapLookup do
  let(:uniqname) { 'rsmoke' }
  let(:group_name) { 'mis-staff' }

  LdapLookup.configuration do |config|
    config.host = "ldap.umich.edu"
    config.base = "dc=umich,dc=edu"
    config.dept_attribute = "umichPostalAddressData"
    config.group_attribute = "umichGroupEmail"
  end

  context 'when given a valid uniqname' do
    it 'returns a Full name' do
      expect(LdapLookup.get_simple_name(uniqname)).to eq'Rick Smoke'
    end

    it 'returns the users dept' do
      expect(LdapLookup.get_dept(uniqname)).to eq'LSA Dean: Mgmt Info Systems'
    end

    it 'returns the users full email address' do
      expect(LdapLookup.get_email(uniqname)).to eq'rsmoke@umich.edu'
    end
  end

  context 'when given a valid group_name and a valid uniqname' do
    it 'returns true' do
      expect(LdapLookup.is_member_of_group?(uniqname, group_name)).to be_truthy
    end
  end

  it 'returns a list of members of a group when given a valid group name' do
    expect(LdapLookup.get_email_distribution_list(group_name)).to include 'members'
  end
end
