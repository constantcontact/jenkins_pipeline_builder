require 'logger'
require 'rspec'

require 'simplecov'
require 'simplecov-rcov'
require 'webmock/rspec'

require File.expand_path('../../../lib/jenkins_pipeline_builder', __FILE__)
require 'rspec/matchers'
require 'equivalent-xml'

RSpec.configure do |config|
  config.before(:each) do
  end
end

RSpec::Matchers.define :have_min_version do |version|
  match do |base|
    @exts = base
    !base.select { |ext| ext.min_version == version }.empty?
  end

  failure_message_for_should do
    "Expected to find extension #{@exts.first.name} with version #{version}, found #{@exts.map { |x| x.min_version }.join(', ')} instead"
  end
end
