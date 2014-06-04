#!/bin/bash
bundle --version || gem install bundler --no-ri --no-rdoc
bundle install
rm -f *.gem
bundle exec rake spec || exit $?
bundle exec gem build jenkins_pipeline_builder.gemspec || exit $?
bundle exec gem bump
