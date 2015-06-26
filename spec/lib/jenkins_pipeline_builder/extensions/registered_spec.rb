require File.expand_path('../../spec_helper', __FILE__)
WRAPPERS = {
  ansicolor: ['0'],
  artifactory: ['0'],
  inject_env_var: ['0'],
  inject_passwords: ['0'],
  maven3artifactory: ['0'],
  nodejs: ['0'],
  rvm: ['0', '0.5'],
  timestamp: ['0'],
  xvfb: ['0']
}
PUBLISHERS = {
  archive_artifact: ['0'],
  brakeman: ['0'],
  claim_broken_build: ['0'],
  cobertura_report: ['0'],
  coverage_result: ['0'],
  description_setter: ['0'],
  downstream: ['0'],
  email_ext: ['0'],
  email_notifications: ['0'],
  git: ['0'],
  groovy_postbuild: ['0'],
  hipchat: ['0', '0.1.9'],
  html_publisher: ['0'],
  junit_result: ['0'],
  performance_plugin: ['0'],
  post_build_script: ['0'],
  publish_tap_results: ['0'],
  sonar_result: ['0'],
  xunit: ['0']
}
BUILDERS = {
  blocking_downstream: ['0'],
  copy_artifact: ['0'],
  inject_vars_file: ['0'],
  maven3: ['0'],
  multi_job: ['0'],
  remote_job: ['0'],
  shell_command: ['0'],
  checkmarx_scan: ['0'],
  system_groovy: ['0']
}
TRIGGERS = {
  git_push: ['0'],
  periodic_build: ['0'],
  scm_polling: ['0'],
  upstream: ['0']
}
JOB_ATTRIBUTES = {
  concurrent_build: ['0'],
  description: ['0'],
  disabled: ['0'],
  discard_old: ['0'],
  hipchat: ['0'],
  inject_env_vars_pre_scm: ['0'],
  parameters: ['0'],
  prepare_environment: ['0'],
  priority: ['0'],
  promoted_builds: ['0'],
  scm_params: ['0', '2.0'],
  throttle: ['0']
}

describe 'built in extensions' do
  before :each do
    @registry = JenkinsPipelineBuilder.registry.registry
  end

  after :each do
    JenkinsPipelineBuilder.registry.clear_versions
  end

  context 'builders' do
    it 'has the correct number' do
      expect(@registry[:job][:builders].size).to eq BUILDERS.size
    end
    BUILDERS.each do |builder, versions|
      it "registers #{builder} correctly" do
        expect(@registry[:job][:builders]).to have_key builder
        expect(@registry[:job][:builders][builder]).to have_registered_versions versions
      end
    end
  end

  context 'triggers' do
    it 'has the correct number' do
      expect(@registry[:job][:triggers].size).to eq TRIGGERS.size
    end

    TRIGGERS.each do |trigger, versions|
      it "registers #{trigger} correctly" do
        expect(@registry[:job][:triggers]).to have_key trigger
        expect(@registry[:job][:triggers][trigger]).to have_registered_versions versions
      end
    end
  end

  context 'job_attributes' do
    it 'has the correct number' do
      expect(@registry[:job].size - 4).to eq JOB_ATTRIBUTES.size
    end

    JOB_ATTRIBUTES.each do |job_attribute, versions|
      it "registers #{job_attribute} correctly" do
        expect(@registry[:job]).to have_key job_attribute
        expect(@registry[:job][job_attribute]).to have_registered_versions versions
      end
    end
  end

  context 'publishers' do
    it 'has the correct number' do
      expect(@registry[:job][:publishers].size).to eq PUBLISHERS.size
    end
    PUBLISHERS.each do |publisher, versions|
      it "registers #{publisher} correctly" do
        expect(@registry[:job][:publishers]).to have_key publisher
        expect(@registry[:job][:publishers][publisher]).to have_registered_versions versions
      end
    end
  end

  context 'wrappers' do
    it 'has the correct number' do
      expect(@registry[:job][:wrappers].size).to eq WRAPPERS.size
    end
    WRAPPERS.each do |wrapper, versions|
      it "registers #{wrapper} correctly" do
        expect(@registry[:job][:wrappers]).to have_key wrapper
        expect(@registry[:job][:wrappers][wrapper]).to have_registered_versions versions
      end
    end
  end
end
