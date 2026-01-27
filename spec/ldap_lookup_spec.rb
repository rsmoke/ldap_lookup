require 'spec_helper'

RSpec.describe LdapLookup do
  let(:valid_uniqname) { 'rsmoke' }
  let(:valid_group_name) { 'mis-staff' }
  let(:invalid_uniqname) { '3mkew' }
  let(:invalid_group_name) { 'bad_group' }

  describe '.get_simple_name' do
    context 'when given a valid uniqname' do
      it 'returns the user\'s display name' do
        result = LdapLookup.get_simple_name(valid_uniqname)
        expect(result).to eq 'Rick Smoke'
      end
    end

    context 'when given an invalid uniqname' do
      it 'returns the default value "not available"' do
        result = LdapLookup.get_simple_name(invalid_uniqname)
        expect(result).to eq 'not available'
      end
    end

    context 'when given nil' do
      it 'returns the default value' do
        result = LdapLookup.get_simple_name(nil)
        expect(result).to eq 'not available'
      end
    end
  end

  describe '.get_email' do
    context 'when given a valid uniqname' do
      it 'returns the user\'s email address' do
        result = LdapLookup.get_email(valid_uniqname)
        expect(result).to eq 'rsmoke@umich.edu'
      end
    end

    context 'when given an invalid uniqname' do
      it 'returns nil' do
        result = LdapLookup.get_email(invalid_uniqname)
        expect(result).to be_nil
      end
    end
  end

  describe '.get_dept' do
    context 'when given a valid uniqname' do
      it 'returns the user\'s department' do
        result = LdapLookup.get_dept(valid_uniqname)
        expect(result).to eq 'LSA Dean: Mgmt Info Systems'
      end
    end

    context 'when given an invalid uniqname' do
      it 'returns nil' do
        result = LdapLookup.get_dept(invalid_uniqname)
        expect(result).to be_nil
      end
    end
  end

  describe '.uid_exist?' do
    context 'when given a valid uniqname' do
      it 'returns true' do
        result = LdapLookup.uid_exist?(valid_uniqname)
        expect(result).to be true
      end
    end

    context 'when given an invalid uniqname' do
      it 'returns false' do
        result = LdapLookup.uid_exist?(invalid_uniqname)
        expect(result).to be false
      end
    end
  end

  describe '.is_member_of_group?' do
    context 'when user is a member of the group' do
      it 'returns true' do
        result = LdapLookup.is_member_of_group?(valid_uniqname, valid_group_name)
        expect(result).to be true
      end
    end

    context 'when user is not a member of the group' do
      it 'returns false' do
        result = LdapLookup.is_member_of_group?(invalid_uniqname, valid_group_name)
        expect(result).to be false
      end
    end

    context 'when group does not exist' do
      it 'returns false' do
        result = LdapLookup.is_member_of_group?(valid_uniqname, invalid_group_name)
        expect(result).to be false
      end
    end

    context 'when both user and group are invalid' do
      it 'returns false' do
        result = LdapLookup.is_member_of_group?(invalid_uniqname, invalid_group_name)
        expect(result).to be false
      end
    end
  end

  describe '.get_email_distribution_list' do
    context 'when given a valid group name' do
      it 'returns a hash with group information' do
        result = LdapLookup.get_email_distribution_list(valid_group_name)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key('group_name')
        expect(result).to have_key('group_email')
        expect(result).to have_key('members')
        expect(result['members']).to be_an(Array)
      end

      it 'includes the members key' do
        result = LdapLookup.get_email_distribution_list(valid_group_name)
        expect(result).to include 'members'
      end

      it 'sorts members alphabetically' do
        result = LdapLookup.get_email_distribution_list(valid_group_name)
        members = result['members']
        expect(members).to eq members.sort if members.any?
      end
    end

    context 'when given an invalid group name' do
      it 'returns a hash without members' do
        result = LdapLookup.get_email_distribution_list(invalid_group_name)
        
        expect(result).to be_a(Hash)
        expect(result).not_to have_key('members')
      end
    end
  end

  describe '.all_groups_for_user' do
    context 'when given a valid uniqname' do
      it 'returns an array of group names' do
        result = LdapLookup.all_groups_for_user(valid_uniqname)
        
        expect(result).to be_an(Array)
        expect(result).to all(be_a(String))
      end

      it 'returns a sorted array' do
        result = LdapLookup.all_groups_for_user(valid_uniqname)
        expect(result).to eq result.sort
      end

      it 'includes groups the user is a member of' do
        result = LdapLookup.all_groups_for_user(valid_uniqname)
        # If the user is a member of the test group, it should be in the list
        if LdapLookup.is_member_of_group?(valid_uniqname, valid_group_name)
          expect(result).to include(valid_group_name)
        end
      end
    end

    context 'when given an invalid uniqname' do
      it 'returns an empty array' do
        result = LdapLookup.all_groups_for_user(invalid_uniqname)
        expect(result).to eq []
      end
    end
  end

  describe '.ldap_connection' do
    context 'when username and password are configured' do
      it 'creates a connection with authentication' do
        expect { LdapLookup.ldap_connection }.not_to raise_error
      end

      it 'uses the correct default bind DN format for user accounts' do
        LdapLookup.configuration do |config|
          config.username = 'testuser'
          config.base = 'dc=umich,dc=edu'
          config.password = 'testpass'
        end
        
        connection = LdapLookup.ldap_connection
        expect(connection).to be_a(Net::LDAP)
      end

      it 'uses custom bind_dn when provided (for service accounts)' do
        custom_bind_dn = 'cn=service-account,ou=Service Accounts,dc=umich,dc=edu'
        
        LdapLookup.configuration do |config|
          config.username = 'serviceuser'
          config.password = 'testpass'
          config.bind_dn = custom_bind_dn
          config.base = 'dc=umich,dc=edu'
        end
        
        connection = LdapLookup.ldap_connection
        expect(connection).to be_a(Net::LDAP)
      end
    end

    context 'when username is missing' do
      it 'raises an error' do
        LdapLookup.configuration do |config|
          config.username = nil
          config.password = 'test'
        end
        
        expect { LdapLookup.ldap_connection }.to raise_error(/LDAP authentication required/)
      end
    end

    context 'when password is missing' do
      it 'raises an error' do
        LdapLookup.configuration do |config|
          config.username = 'testuser'
          config.password = nil
        end
        
        expect { LdapLookup.ldap_connection }.to raise_error(/LDAP authentication required/)
      end
    end
  end

  describe 'encryption configuration' do
    context 'with STARTTLS encryption' do
      it 'configures STARTTLS encryption' do
        LdapLookup.configuration do |config|
          config.encryption = :start_tls
          config.port = '389'
        end
        
        expect { LdapLookup.ldap_connection }.not_to raise_error
      end
    end

    context 'with LDAPS encryption' do
      it 'configures simple TLS encryption' do
        LdapLookup.configuration do |config|
          config.encryption = :simple_tls
          config.port = '636'
        end
        
        expect { LdapLookup.ldap_connection }.not_to raise_error
      end
    end
  end

  describe '.get_user_attribute' do
    context 'when attribute exists' do
      it 'returns the attribute value' do
        result = LdapLookup.get_user_attribute(valid_uniqname, 'mail')
        expect(result).to eq 'rsmoke@umich.edu'
      end
    end

    context 'when attribute does not exist' do
      it 'returns the default value' do
        result = LdapLookup.get_user_attribute(valid_uniqname, 'nonexistent', 'default')
        expect(result).to eq 'default'
      end
    end
  end

  describe '.get_nested_attribute' do
    context 'when nested attribute exists' do
      it 'returns the nested attribute value' do
        result = LdapLookup.get_nested_attribute(valid_uniqname, 'umichpostaladdressdata.addr1')
        expect(result).to eq 'LSA Dean: Mgmt Info Systems'
      end
    end

    context 'when nested attribute does not exist' do
      it 'returns nil' do
        result = LdapLookup.get_nested_attribute(invalid_uniqname, 'umichpostaladdressdata.addr1')
        expect(result).to be_nil
      end
    end
  end
end
