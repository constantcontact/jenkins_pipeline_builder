require 'rspec'
require 'rspec/matchers'

require 'simplecov'
require 'simplecov-rcov'
require 'webmock/rspec'
require 'equivalent-xml'

require File.expand_path('../../../lib/jenkins_pipeline_builder', __dir__)

RSpec::Matchers.define :have_min_version do |version|
  match do |base|
    @set = base
    !base.extensions.select { |ext| ext.min_version == version }.empty?
  end

  failure_message do
    versions = @set.map(&:min_version).join(', ')
    "Expected to find extension #{@set.name} with version #{version}, found #{versions} instead"
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define :have_registered_versions do |versions|
  match do |set|
    @set = set
    @registered_versions = set.versions.keys.map(&:version)
    @registered_versions.sort == versions.sort
  end

  failure_message do
    "Expected #{@set.name} to have registered versions #{versions}. Got #{@registered_versions}"
  end
end

def parse_expectation_xml(xml_string)
  Nokogiri::XML.parse(xml_string, &:noblanks)
end
