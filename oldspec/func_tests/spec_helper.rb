require 'logger'
require 'rspec'
require 'webmock/rspec'
require 'simplecov'

require File.expand_path('../../../lib/jenkins_pipeline_builder', __FILE__)

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run_excluding broken:  true

  config.before(:each) do
  end

  WebMock.disable_net_connect!(allow_localhost: true)
end
