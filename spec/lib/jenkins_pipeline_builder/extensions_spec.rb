require File.expand_path('../spec_helper', __FILE__)

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

describe JenkinsPipelineBuilder::ExtensionSet do
  subject(:set) { JenkinsPipelineBuilder::ExtensionSet.new('foo') {} }

  before :each do
    set.name 'example'
  end

  context 'xml' do
    it 'returns the block for the correct version'
    it 'sets the min_version if a parameter is provided' do
      set.xml version: '0.2' do
        true
      end
      expect(set.blocks).to have_key '0.2'
    end
    it 'uses the path if provided' do
      set.xml path: 'foo' do
        true
      end
      expect(set.blocks['0'][:path]).to eq 'foo'
    end
  end

  context '#extension' do
    def new_ext(version = '0.0')
      ext = JenkinsPipelineBuilder::Extension.new
      ext.name 'foo'
      ext.plugin_id 'foo'
      ext.min_version version
      ext.xml -> { true }
      ext.type 'foo'
      ext.path 'foo'
      ext
    end

    def ext_versions(versions)
      versions.each do |v|
        ext = new_ext(v)
        expect(ext).to be_valid
        set.extensions << ext
      end

      expect(set).to be_valid
      expect(set.extensions.size).to eq versions.size
    end

    it 'returns an extension' do
      ext_versions ['0.0']
      set.installed_version = '0.1'
      expect(set.extension).to be_kind_of JenkinsPipelineBuilder::Extension
    end

    it 'returns the highest that is lower than the installed version' do
      ext_versions ['0.0', '0.2']

      set.installed_version = '0.1'

      expect(set.extension.min_version).to eq '0.0'
    end

    it 'returns highest available if the installed version is higher' do
      ext_versions ['0.0', '0.2']

      set.installed_version = '0.3'

      expect(set.extension.min_version).to eq '0.2'
    end

    it 'works for complicated version comparions' do
      ext_versions ['10.5', '9.2', '100.4']

      set.installed_version = '11.3'

      expect(set.extension.min_version).to eq '10.5'
    end

    it 'raises an error if the registered versions are too high' do
      ext_versions ['10.5', '9.2']

      set.installed_version = '1.3'

      expect { set.extension.min_version }.to raise_error
    end

    it 'works for snapshot/beta stuff' do
      ext_versions ['1.9', '2.3']

      set.installed_version = '2.0-SNAPSHOT (private-06/06/2014 09:51-bgaulin)'
      # Other examples
      # set.installed_version = '2.0-beta-1'
      # set.installed_version = '2.0+build.93'
      # set.installed_version = '2.0.8'
      expect(set.extension.min_version).to eq '1.9'
    end
  end
end
