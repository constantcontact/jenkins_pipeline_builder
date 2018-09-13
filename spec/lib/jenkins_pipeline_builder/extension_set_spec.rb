require File.expand_path('spec_helper', __dir__)

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

  context '#installed_version' do
    it 'parses three digits' do
      set.installed_version = '0.1.2'
      expect(set.installed_version.version).to eq '0.1.2'
    end

    it 'parses only two digits' do
      set.installed_version = '0.1'
      expect(set.installed_version.version).to eq '0.1'
    end
  end

  context '#versions' do
    it 'does not memoize itself' do
      set.add_extension 'builder', '0', description: :first
      set.versions
      set.add_extension 'builder', '0', description: :second
      expect(set.versions[Gem::Version.new('0')].description).to eq :second
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

      set.installed_version = '2.0-SNAPSHOT'
      # Other examples
      # set.installed_version = '2.0-beta-1'
      # set.installed_version = '2.0+build.93'
      # set.installed_version = '2.0.8'
      expect(set.extension.min_version).to eq '1.9'
    end
  end
end
