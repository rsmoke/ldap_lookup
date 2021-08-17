require 'ldap_lookup'

RSpec.describe LdapLookup do
  let(:uniqname) { 'rsmoke' }
  let(:group_name) { 'mis-staff' }

  let(:bad_uniqname) { '3mkew' }
  let(:bad_group_name) { 'bad_group' }

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
    it 'returns true if user is a member of the group' do
      expect(LdapLookup.is_member_of_group?(uniqname, group_name)).to be_truthy
    end
  end

  it 'returns a list of members of a group when given a valid group name' do
    expect(LdapLookup.get_email_distribution_list(group_name)).to include 'members'
  end

  context 'when given an invalid uniqname' do
    it 'returns nil when looking users full name' do
      expect(LdapLookup.get_simple_name(bad_uniqname)).to eq'not available'
    end

    it 'returns nil when looking up users department' do
      expect(LdapLookup.get_dept(bad_uniqname)).to be_nil
    end

    it 'returns nil looking up user full email' do
      expect(LdapLookup.get_email(bad_uniqname)).to be_nil
    end
  end

  context 'when given an invalid group_name and an invalid uniqname' do
    it 'returns false when checking users membership' do
      expect(LdapLookup.is_member_of_group?(bad_uniqname, bad_group_name)).to be_falsy
    end
  end

  it 'returns an empty list of members of a group when given a valid group name' do
    expect(LdapLookup.get_email_distribution_list(bad_group_name)).not_to include 'members'
  end
end
