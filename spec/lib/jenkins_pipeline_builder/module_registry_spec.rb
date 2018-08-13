require File.expand_path('spec_helper', __dir__)

describe JenkinsPipelineBuilder::ModuleRegistry do
  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end
  describe '#register' do
    it 'should return item by a specified path' do
      registry = JenkinsPipelineBuilder::ModuleRegistry.new
      set = double
      allow(set).to receive(:name).and_return :foo
      registry.register [:job], set

      expect(registry.get('job/foo').name).to eq :foo
    end
  end

  describe '#initialize' do
  end

  describe '#version' do
    before :all do
      JenkinsPipelineBuilder.credentials = {
        server_ip: '127.0.0.1',
        server_port: 8080,
        username: 'username',
        password: 'password',
        log_location: '/dev/null'
      }
    end

    it 'pulls the version from the registry if it is not memoized' do
      subject.clear_versions
      expect(JenkinsPipelineBuilder).to receive(:debug).and_return false
      expect(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(list_installed: { 'one' => '0.1' })
      subject.versions
    end
  end

  describe '#entries' do
  end

  describe '#get' do
  end

  describe '#get_by_path_collection' do
  end

  describe '#traverse_registry_path' do
  end

  describe '#traverse_registry' do
  end

  describe '#execute_extension' do
  end

  describe 'executing a registry item' do
    before :all do
      class XmlException < StandardError
      end
      class BeforeException < StandardError
      end
      class AfterException < StandardError
      end
      JenkinsPipelineBuilder.credentials = {
        server_ip: '127.0.0.1',
        server_port: 8080,
        username: 'username',
        password: 'password',
        log_location: '/dev/null'
      }
    end

    let(:params) { { wrappers: { test_name: :foo } } }

    before :each do
      allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
        list_installed: { 'test_name' => '20.0', 'unorderedTest' => '20.0' }
      )
      @n_xml = Nokogiri::XML::Document.new

      wrapper do
        name :test_name
        plugin_id 'test_name'

        xml do
          true
        end
      end
      expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :test_name
      @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:test_name].extension
    end

    after :each do
      JenkinsPipelineBuilder.registry.registry[:job][:wrappers].delete :test_name
    end

    it 'calls the xml block when executing the item' do
      @ext.xml ->(_) { raise XmlException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error XmlException
    end

    it 'calls the before block' do
      @ext.before ->(_) { raise BeforeException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error BeforeException
    end

    it 'calls the after block' do
      @ext.after ->(_) { raise AfterException, 'foo' }

      expect do
        JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      end.to raise_error AfterException
    end

    context 'unordered dsl' do
      let(:params) { { wrappers: { unordered_test: :foo } } }

      after :each do
        JenkinsPipelineBuilder.registry.registry[:job][:wrappers].delete :unordered_test
      end

      it 'works with before first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          before do
            raise BeforeException, 'foo'
          end

          xml do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error BeforeException
      end

      it 'works with after first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          after do
            raise AfterException, 'foo'
          end

          xml do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error AfterException
      end

      it 'works with xml first' do
        wrapper do
          name :unordered_test
          plugin_id 'unorderedTest'

          xml do
            raise XmlException, 'foo'
          end

          after do
            true
          end
        end

        expect(JenkinsPipelineBuilder.registry.registry[:job][:wrappers]).to have_key :unordered_test
        @ext = JenkinsPipelineBuilder.registry.registry[:job][:wrappers][:unordered_test].extension

        expect do
          JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
        end.to raise_error XmlException
      end
    end
  end
end
