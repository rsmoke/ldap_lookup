require 'spec_helper'
require 'helpers/configuration'

RSpec.describe Configuration do
  let(:dummy_class) { Class.new { extend Configuration } }
  let(:host_name) { 'ldap.somecompany.com' }
  let(:port_number) { '389' }
  let(:base_dn) { 'dc=example,dc=com' }

  describe '.define_setting' do
    context 'with a default value' do
      it 'defines a configuration setting with default value' do
        dummy_class.define_setting('host', host_name)
        expect(dummy_class.host).to eq(host_name)
      end

      it 'allows setting the value via configuration block' do
        dummy_class.define_setting('host', 'default.com')
        dummy_class.configuration { |c| c.host = host_name }
        expect(dummy_class.host).to eq(host_name)
      end

      it 'allows reading the value via configuration block' do
        dummy_class.define_setting('host', host_name)
        result = dummy_class.configuration { |c| c.host }
        expect(result).to eq(host_name)
      end
    end

    context 'without a default value' do
      it 'sets value to nil for undefined setting' do
        dummy_class.define_setting('nothing')
        expect(dummy_class.nothing).to be_nil
      end

      it 'allows setting the value after definition' do
        dummy_class.define_setting('custom_setting')
        dummy_class.configuration { |c| c.custom_setting = 'test_value' }
        expect(dummy_class.custom_setting).to eq('test_value')
      end
    end

    context 'with multiple settings' do
      it 'defines and manages multiple independent settings' do
        dummy_class.define_setting('host', host_name)
        dummy_class.define_setting('port', port_number)
        dummy_class.define_setting('base', base_dn)

        expect(dummy_class.host).to eq(host_name)
        expect(dummy_class.port).to eq(port_number)
        expect(dummy_class.base).to eq(base_dn)
      end

      it 'allows updating settings independently' do
        dummy_class.define_setting('host', 'old.com')
        dummy_class.define_setting('port', '389')

        dummy_class.configuration do |c|
          c.host = 'new.com'
          c.port = '636'
        end

        expect(dummy_class.host).to eq('new.com')
        expect(dummy_class.port).to eq('636')
      end
    end
  end

  describe '.configuration' do
    it 'yields self to the block' do
      yielded_object = nil
      dummy_class.configuration { |c| yielded_object = c }
      expect(yielded_object).to eq(dummy_class)
    end

    it 'returns the result of the block' do
      result = dummy_class.configuration { |c| 'test_result' }
      expect(result).to eq('test_result')
    end
  end

  describe 'setting and getting values' do
    before do
      dummy_class.define_setting('test_setting', 'default')
    end

    it 'provides a setter method' do
      dummy_class.test_setting = 'new_value'
      expect(dummy_class.test_setting).to eq('new_value')
    end

    it 'provides a getter method' do
      expect(dummy_class.test_setting).to eq('default')
    end

    it 'persists values between calls' do
      dummy_class.test_setting = 'persisted'
      expect(dummy_class.test_setting).to eq('persisted')
      expect(dummy_class.test_setting).to eq('persisted')
    end
  end
end
