require File.expand_path('spec_helper', __dir__)

describe JenkinsPipelineBuilder::Extension do
  subject(:extension) { JenkinsPipelineBuilder::Extension.new }
  context 'defaults' do
    it 'min_version is nil' do
      expect(extension.min_version).to be nil
    end
    it 'name is nil' do
      expect(extension.name).to be nil
    end
    it 'plugin_id is nil' do
      expect(extension.plugin_id).to be nil
    end
    it 'type is nil' do
      expect(extension.type).to be nil
    end
    it 'path is nil' do
      expect(extension.path).to be nil
    end
    it 'announced is true' do
      expect(extension.announced).to be true
    end
    it 'jenkins_name has the correct default' do
      expect(extension.jenkins_name).to eq 'No jenkins display name set'
    end
    it 'description has the correct default' do
      expect(extension.description).to eq 'No description set'
    end
  end

  context 'methods' do
    context 'check_parameters' do
      it 'accepts a valid param' do
        extension.parameters [:foo]
        expect(extension.check_parameters(foo: :bar)).to eq []
      end

      it 'fails with an invalid param' do
        extension.parameters [:foo]
        extension.name 'name'
        expect(extension.check_parameters(bar: :baz)).to eq ['Extension name does not support parameter bar']
      end
    end
    context 'name' do
      it 'sets the name if a parameter is provided' do
        extension.name('foo')
        expect(extension.name).to eq 'foo'
      end
    end
    context 'plugin_id' do
      it 'sets the plugin_id if a parameter is provided' do
        extension.plugin_id('foo')
        expect(extension.plugin_id).to eq 'foo'
      end
    end
    context 'jenkins_name' do
      it 'sets the jenkins_name if a parameter is provided' do
        extension.jenkins_name('foo')
        expect(extension.jenkins_name).to eq 'foo'
      end
    end
    context 'description' do
      it 'sets the description if a parameter is provided' do
        extension.description('foo')
        expect(extension.description).to eq 'foo'
      end
    end
    context 'path' do
      it 'sets the path if a parameter is provided' do
        extension.path('foo')
        expect(extension.path).to eq 'foo'
      end
    end
    context 'announced' do
      it 'sets the announced if a parameter is provided' do
        extension.announced('foo')
        expect(extension.announced).to eq 'foo'
      end
    end
    context 'type' do
      it 'sets the type if a parameter is provided' do
        extension.type('foo')
        expect(extension.type).to eq 'foo'
      end
    end
    context 'min_version' do
      it 'sets the min_version if a parameter is provided' do
        extension.min_version('foo')
        expect(extension.min_version).to eq 'foo'
      end
    end
    context 'xml' do
      it 'saves the block' do
        extension.xml -> { true }
        expect(extension.xml.call).to be true
      end
      it 'returns the saved block if there none is provided' do
        extension.xml -> { true }
        expect(extension.xml).to be_kind_of Proc
      end
    end
    context 'after' do
      it 'saves the block' do
        extension.after -> { true }
        expect(extension.after.call).to be true
      end
      it 'returns the saved block if there none is provided' do
        extension.after -> { true }
        expect(extension.after).to be_kind_of Proc
      end
    end
    context 'before' do
      it 'saves the block' do
        extension.before -> { true }
        expect(extension.before.call).to be true
      end
      it 'returns the saved block if there none is provided' do
        extension.before -> { true }
        expect(extension.before).to be_kind_of Proc
      end
    end
    context 'valid?' do
      it 'returns true if errors is empty' do
        extension.name 'foo'
        extension.plugin_id 'foo'
        extension.min_version '0.2'
        extension.xml -> { true }
        extension.type 'foo'
        extension.path 'foo'
        expect(extension.errors).to be_empty
        expect(extension.valid?).to be true
      end

      it 'returns false if errors is not empty' do
        expect(extension.errors).to_not be_empty
        expect(extension.valid?).to be false
      end
    end
  end
end
