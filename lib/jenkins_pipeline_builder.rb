#
# Copyright (c) 2014 Constant Contact
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

require 'active_support'
require 'active_support/core_ext'

require 'jenkins_pipeline_builder/version'
require 'jenkins_pipeline_builder/utils'
require 'jenkins_pipeline_builder/custom_errors'
require 'jenkins_pipeline_builder/compiler'
require 'jenkins_pipeline_builder/module_registry'
require 'jenkins_pipeline_builder/pull_request_generator'
require 'jenkins_pipeline_builder/view'
require 'jenkins_pipeline_builder/job_collection'
require 'jenkins_pipeline_builder/job'
require 'jenkins_pipeline_builder/promotion'
require 'jenkins_pipeline_builder/remote_dependencies'
require 'jenkins_pipeline_builder/generator'

module JenkinsPipelineBuilder
  class << self
    attr_reader :client, :credentials, :debug, :file_mode
    attr_writer :logger
    def generator
      @generator ||= Generator.new
    end

    def file_mode!
      @file_mode = true
    end

    def normal_mode!
      @file_mode = false
    end

    def debug!
      @debug = true
      logger.level = Logger::DEBUG
    end

    def no_debug!
      @debug = false
      logger.level = Logger::INFO
    end

    def credentials=(creds)
      @credentials = creds
      @client = JenkinsApi::Client.new(credentials)
      @credentials
    end

    def logger
      @logger ||= client ? client.logger : Logger.new(STDOUT)
    end

    def registry
      generator.module_registry
    end
  end
end

JenkinsPipelineBuilder.generator
require 'jenkins_pipeline_builder/extensions'
require 'jenkins_pipeline_builder/extension_dsl'
require 'jenkins_pipeline_builder/extension_set'
require 'jenkins_pipeline_builder/extensions/helpers/extension_helper'
Dir[File.join(File.dirname(__FILE__), 'jenkins_pipeline_builder/extensions/helpers/**/*.rb')].sort.each do |file|
  require file
end

require 'jenkins_pipeline_builder/extensions/builders'
require 'jenkins_pipeline_builder/extensions/job_attributes'
require 'jenkins_pipeline_builder/extensions/wrappers'
require 'jenkins_pipeline_builder/extensions/publishers'
require 'jenkins_pipeline_builder/extensions/triggers'
require 'jenkins_pipeline_builder/extensions/build_steps'
require 'jenkins_pipeline_builder/extensions/promotion_conditions'

require 'jenkins_pipeline_builder/cli/helper'
require 'jenkins_pipeline_builder/cli/view'
require 'jenkins_pipeline_builder/cli/pipeline'
require 'jenkins_pipeline_builder/cli/list'
require 'jenkins_pipeline_builder/cli/describe'
require 'jenkins_pipeline_builder/cli/base'
