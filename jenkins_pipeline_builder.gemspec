lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jenkins_pipeline_builder/version'

Gem::Specification.new do |spec|
  spec.name          = 'jenkins_pipeline_builder'
  spec.version       = JenkinsPipelineBuilder::VERSION
  spec.authors       = ['Igor Moochnick', 'Joseph Henrich']
  spec.email         = %w[igor.moochnick@gmail.com crimsonknave@gmail.com]
  spec.description   = 'This is a simple and easy-to-use Jenkins Pipeline generator with features focused on
automating Job & Pipeline creation from the YAML files checked-in with your application source code'
  spec.summary       = 'This gem is will boostrap your Jenkins pipelines'
  spec.homepage      = 'https://github.com/ConstantContact/jenkins_pipeline_builder'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '~> 4.2.6'
  spec.add_dependency 'jenkins_api_client', '~> 1.0.0'
  spec.add_dependency 'minitar'
  spec.add_dependency 'mixlib-shellout', '= 2.2.7' # maintaining backwards compatibility with ruby 2.1.5
  spec.add_dependency 'nokogiri', '~> 1.6.0'
  spec.add_dependency 'thor', '>= 0.18.0'

  spec.add_development_dependency 'bump'
  spec.add_development_dependency 'byebug', '= 11.0.1' # last version with compatibility with ruby 2.3.x
  spec.add_development_dependency 'equivalent-xml', '= 0.6.0' # last version with compatibility with ruby 2.3.x
  spec.add_development_dependency 'gem-release'
  spec.add_development_dependency 'json'
  spec.add_development_dependency 'kwalify'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rubocop', '= 0.81' # last version with compatibility with ruby 2.3.x
  spec.add_development_dependency 'simplecov', '= 0.17.1' # last version with compatibility with ruby 2.3.x
  spec.add_development_dependency 'simplecov-rcov'
  spec.add_development_dependency 'webmock', '~> 1.0'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'yard-thor'
end
