require 'rspec'

require 'simplecov'
require 'simplecov-rcov'
require 'webmock/rspec'

require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)

RSpec::Matchers.define :have_min_version do |version|
  match do |base|
    @exts = base
    !base.select { |ext| ext.min_version == version }.empty?
  end

  failure_message_for_should do
    versions = @exts.map { |x| x.min_version }.join(', ')
    "Expected to find extension #{@exts.first.name} with version #{version}, found #{versions} instead"
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
