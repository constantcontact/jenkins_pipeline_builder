require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'needs more tests'
  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new
    ext = double
    allow(ext).to receive(:name).and_return :foo
    registry.register [:job], ext

    expect(registry.get('job/foo').first.name).to eq :foo
  end

  it 'registered the builders correctly' do
    builders = {
      multi_job: [0],
      maven3: [0],
      shell_command: [0],
      inject_vars_file: [0],
      blocking_downstream: [0],
      remote_job: [0],
      copy_artifact: [0]
    }
    registry = JenkinsPipelineBuilder.registry.registry
    expect(registry[:job][:builders].size).to eq builders.size
    builders.each do |builder, versions|
      expect(registry[:job][:builders]).to have_key builder

      versions.each do |version|
        expect(registry[:job][:builders][builder]).to have_min_version version
      end
    end
  end
  it 'registered the triggers correctly' do
    triggers = {
      git_push: [0],
      scm_polling: [0],
      periodic_build: [0],
      upstream: [0]
    }
    registry = JenkinsPipelineBuilder.registry.registry
    expect(registry[:job][:triggers].size).to eq triggers.size
    triggers.each do |trigger, versions|
      expect(registry[:job][:triggers]).to have_key trigger

      versions.each do |version|
        expect(registry[:job][:triggers][trigger]).to have_min_version version
      end
    end
  end
  it 'registered the job_attributes correctly' do
    job_attributes = {
      description: [0],
      scm_params: [0],
      hipchat: [0],
      priority: [0],
      parameters: [0],
      discard_old: [0],
      throttle: [0],
      prepare_environment: [0],
      concurrent_build: [0]
    }
    registry = JenkinsPipelineBuilder.registry.registry
    # There are 4 sub types so, we don't count those
    expect(registry[:job].size - 4).to eq job_attributes.size
    job_attributes.each do |job_attribute, versions|
      expect(registry[:job]).to have_key job_attribute

      versions.each do |version|
        expect(registry[:job][job_attribute]).to have_min_version version
      end
    end
  end
  it 'registered the publishers correctly' do
    publishers = {
      description_setter: [0],
      downstream: [0],
      hipchat: [0],
      git: [0],
      junit_result: [0],
      coverage_result: [0],
      post_build_script: [0],
      groovy_postbuild: [0],
      archive_artifact: [0],
      email_notifications: [0]
    }
    registry = JenkinsPipelineBuilder.registry.registry
    expect(registry[:job][:publishers].size).to eq publishers.size
    publishers.each do |publisher, versions|
      expect(registry[:job][:publishers]).to have_key publisher

      versions.each do |version|
        expect(registry[:job][:publishers][publisher]).to have_min_version version
      end
    end
  end
  it 'registered the wrappers correctly' do
    wrappers = {
      ansicolor: [0],
      timestamp: [0],
      name: [0],
      rvm: ['0', '0.5'],
      inject_passwords: [0],
      inject_env_var: [0],
      artifactory: [0],
      maven3artifactory: [0]
    }
    registry = JenkinsPipelineBuilder.registry.registry
    expect(registry[:job][:wrappers].size).to eq wrappers.size
    wrappers.each do |wrapper, versions|
      expect(registry[:job][:wrappers]).to have_key wrapper

      versions.each do |version|
        expect(registry[:job][:wrappers][wrapper]).to have_min_version version
      end
    end
  end
end
