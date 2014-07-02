require 'rspec'

require 'simplecov'
require 'simplecov-rcov'
require 'webmock/rspec'

SimpleCov.profiles.define 'spec' do
  add_group 'jenkins_pipeline_builder', '/lib/'
  coverage_dir 'out/coverage'
  formatter SimpleCov::Formatter::MultiFormatter[
                SimpleCov::Formatter::Console,
                SimpleCov::Formatter::RcovFormatter,
            ]
end

class SimpleCov::Formatter::Console
  def format(result)
    print "COVERAGE: #{result.covered_percent.round(2)}%\n"
  end
end

SimpleCov.start 'spec'

require File.expand_path('../../../../lib/jenkins_pipeline_builder', __FILE__)
