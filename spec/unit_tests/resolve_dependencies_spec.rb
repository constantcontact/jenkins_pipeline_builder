require File.expand_path('../spec_helper', __FILE__)

describe 'Templates resolver' do
  before(:each) do
    JenkinsPipelineBuilder.credentials = {
      server_ip: '127.0.0.1',
      server_port: 8080,
      username: 'username',
      password: 'password',
      log_location: '/dev/null'
    }
    @generator = JenkinsPipelineBuilder.generator
    JenkinsPipelineBuilder.client
    @generator.debug = true
    @generator.no_files = true
  end

  after :each do
    JenkinsPipelineBuilder.generator.instance_variable_set(:@job_collection, {})
  end

  describe 'resolving settings bags' do
    it 'gives a bag when all the variables can be resolved' do
      str = %(
- project:
    name: project-name
    db: my_own_db_{{else}}
      )
      project = YAML.load(str)
      @generator.load_job_collection project

      # @generator.resolve_item('project-name')
      settings = JenkinsPipelineBuilder::Compiler.get_settings_bag(@generator.get_item('project-name'), db: 'blah', else: 'bum')
      settings.should == { name: 'project-name', db: 'my_own_db_bum', else: 'bum' }
    end

    it 'returns nil when all the variables cant be resolved' do
      str = %(
- project:
    name: project-name
    db: my_own_db_{{else}}_{{blah}}
      )
      project = YAML.load(str)
      @generator.load_job_collection project

      # @generator.resolve_item('project-name')
      settings = JenkinsPipelineBuilder::Compiler.get_settings_bag(@generator.get_item('project-name'), db: 'blah', else: 'bum')
      settings.should be_nil
    end
  end

  it 'starts with the defaults section for settings bag' do
    str = %(
- defaults:
    name: global
    description: 'Do not edit this job through the web!'
- job-template:
    name: 'foo-bar'
    description: '{{description}}'
    builders:
      - shell: perftest
- project:
    name: project-name
    db: my_own_db
    jobs:
      - 'foo-bar'
      )
    project = YAML.load(str)
    @generator.load_job_collection project

    success, project = @generator.resolve_project(@generator.get_item('project-name'))

    expect(success).to be_true
    expect(project).to eq(
      name: 'project-name',
      type: :project,
      value: {
        name: 'project-name',
        db: 'my_own_db',
        jobs: [{
          :"foo-bar" => {},
          result: {
            name: 'foo-bar',
            description: 'Do not edit this job through the web!',
            builders: [{
              shell: 'perftest' }]
          }
        }]
      },
      settings: {
        name: 'project-name',
        description: 'Do not edit this job through the web!',
        db: 'my_own_db'
      }
    )
  end

  it 'should build project collection from jobs templates' do
    str = %(
- job-template:
    name: '{{name}}-unit-tests'
    builders:
      - shell: unittest
    publishers:
      - email:
          recipients: '{{mail-to}}'

- job-template:
    name: '{{name}}-perf-tests'
    builders:
      - shell: perftest
    publishers:
      - email:
          recipients: '{{mail-to}}'

- project:
    name: project-name
    db: my_own_db
    jobs:
      - '{{name}}-unit-tests':
          mail-to: developer@nowhere.net
      - '{{name}}-perf-tests':
          mail-to: projmanager@nowhere.net
)

    project = YAML.load(str)
    @generator.load_job_collection project

    success, project = @generator.resolve_project(@generator.get_item('project-name'))
    expect(success).to be_true
    expect(project).to eq(
      name: 'project-name',
      type: :project,
      value: {
        name: 'project-name',
        db: 'my_own_db',
        jobs: [{
          :"{{name}}-unit-tests" => { :"mail-to" => 'developer@nowhere.net' },
          result: {
            name: 'project-name-unit-tests',
            builders: [{ shell: 'unittest' }],
            publishers: [{ email: { recipients: 'developer@nowhere.net' } }]
          }
        }, {
          :"{{name}}-perf-tests" => { :"mail-to" => 'projmanager@nowhere.net' },
          result: {
            name: 'project-name-perf-tests',
            builders: [{ shell: 'perftest' }],
            publishers: [{ email: { recipients: 'projmanager@nowhere.net' } }]
          }
        }]
      },
      settings: { name: 'project-name', db: 'my_own_db' }
    )
  end

  it 'should build project collection from jobs and jobs templates' do
    str = %(
- job-template:
    name: '{{name}}-unit-tests'
    builders:
      - shell: unittest
    publishers:
      - email:
          recipients: '{{mail-to}}'

- job:
    name: 'foo-bar'
    builders:
      - shell: perftest

- project:
    name: project-name
    db: my_own_db
    jobs:
      - 'foo-bar'
      - '{{name}}-unit-tests':
          mail-to: projmanager@nowhere.net
)

    project = YAML.load(str)
    @generator.load_job_collection project

    success, project = @generator.resolve_project(@generator.get_item('project-name'))
    expect(success).to be_true
    expect(project).to eq(
      name: 'project-name',
      type: :project,
      value:  {
        name: 'project-name',
        db: 'my_own_db',
        jobs:  [{
          :"foo-bar" => {},
          result:  {
            name: 'foo-bar',
            builders: [{ shell: 'perftest' }]
          }
        }, {
          :"{{name}}-unit-tests" => { :"mail-to" => 'projmanager@nowhere.net' },
          result:  {
            name: 'project-name-unit-tests',
            builders: [{ shell: 'unittest' }],
            publishers: [{ email: { recipients: 'projmanager@nowhere.net' } }]
          }
        }]
      },
      settings: { name: 'project-name', db: 'my_own_db' }
    )
  end

  describe 'compilation of templates' do
    it 'compiles String' do
      success, string = JenkinsPipelineBuilder::Compiler.compile('blah', item1: 'data1')
      expect(success).to be_true
      expect(string).to eq 'blah'
    end

    it 'compiles simple Hash' do
      success, hash = JenkinsPipelineBuilder::Compiler.compile({ name: 'item-{{item1}}', value: 'item1-data' }, item1: 'data1')
      expect(success).to be_true
      expect(hash).to eq(name: 'item-data1', value: 'item1-data')
    end

    it 'compiles nested Hash' do
      success, hash = JenkinsPipelineBuilder::Compiler.compile({ name: 'item-{{item1}}', value: { house: 'house-{{item1}}' } }, item1: 'data1')
      expect(success).to be_true
      expect(hash).to eq(name: 'item-data1', value: { house: 'house-data1' })
    end

    it 'compiles complex Hash' do
      template = { name: '{{name}}-unit-tests',
                   builders: [{ shell: 'unittest' }],
                   publishers: [{ email: { recipients: '{{mail-to}}' } }] }
      settings = { name: 'project-name', db: 'my_own_db', :'mail-to' => 'developer@nowhere.net' }

      success, hash = JenkinsPipelineBuilder::Compiler.compile(template, settings)
      expect(success).to be_true
      expect(hash).to eq(
          name: 'project-name-unit-tests',
          builders: [{ shell: 'unittest' }],
          publishers: [{ email: { recipients: 'developer@nowhere.net' } }])
    end
  end

  it 'shoult resolve job template into a job' do
    file = 'project_with_jobs'
    path = File.expand_path('../fixtures/templates/' + file, __FILE__)
    project = YAML.load_file(path + '.yaml')

    @generator.load_job_collection project

    success, job = @generator.resolve_job_by_name('{{name}}-unit-tests', name: 'project-name', db: 'my_own_db', :'mail-to' => 'developer@nowhere.net')
    expect(success).to be_true
    expect(job).to eq(
      name: 'project-name-unit-tests',
      builders: [{ shell: 'unittest' }],
      publishers: [{ email: { recipients: 'developer@nowhere.net' } }])
  end

  it 'should load from folder' do
    path = File.expand_path('../fixtures/templates/', __FILE__)
    @generator.load_collection_from_path(path)

    @generator.job_collection.count.should eq 4
    @generator.projects.count.should eq 1
  end
end
