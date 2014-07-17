#!/bin/bash
bundle --version || gem install bundler --no-ri --no-rdoc
bundle install
bundle exec rake spec || exit $?