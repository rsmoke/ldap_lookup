require 'helpers/configuration'

RSpec.describe Configuration do
  let(:dummy_class) { Class.new { extend Configuration } }
  let(:host_name) { 'ldap.somecompany.com' }

  it 'defines configuration settings' do
    dummy_class.define_setting('host', 'ldap.somecompany.com')
    expect(dummy_class.configuration { |c| c.host }).to eq(host_name)
  end

  it 'sets value to nil for undefined setting' do
    dummy_class.define_setting('nothing')
    expect(dummy_class.configuration { |u| u.nothing }).to be_nil
  end
end
