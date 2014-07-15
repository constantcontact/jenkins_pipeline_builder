require 'rspec'

require 'simplecov'
require 'simplecov-rcov'
require 'webmock/rspec'

require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)

RSpec::Matchers.define :have_min_version do |version|
  match do |base|
    @set = base
    !base.extensions.select { |ext| ext.min_version == version }.empty?
  end

  failure_message do
    versions = @set.map { |x| x.min_version }.join(', ')
    "Expected to find extension #{@set.name} with version #{version}, found #{versions} instead"
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
