require File.expand_path('spec_helper', __dir__)

describe 'extension dsl' do
  before :all do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
  end

  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  it 'overrides included extensions with local ones' do
    builder do
      name :shell_command
      plugin_id 'builtin'
      description 'Lets you run shell commands as a build step.'
      jenkins_name 'Execute shell'
      announced false

      xml do |param|
        newShell do
          command param
        end
      end
    end

    allow(JenkinsPipelineBuilder.client).to receive(:plugin).and_return double(
      list_installed: { 'parameterized-trigger' => '20.0' }
    )

    @n_xml = Nokogiri::XML::Builder.new { |xml| xml.builders }.doc
    params = { builders: { shell_command: 'asdf' } }
    JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)

    builder = @n_xml.root.children.first
    expect(builder.name).to match 'newShell'
  end
end
