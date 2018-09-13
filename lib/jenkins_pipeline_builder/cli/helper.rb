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

require 'fileutils'
require 'yaml'
require 'json'
require 'jenkins_api_client'
require 'open-uri'
require 'zlib'
require 'archive/tar/minitar'
require 'resolv'

module JenkinsPipelineBuilder
  module CLI
    # This is the helper class that sets up the credentials from the command
    # line parameters given and initializes the Jenkins Pipeline Builder.
    class Helper
      class << self
        attr_accessor :jenkins_api_creds
      end

      DEFAULT_FILE_FORMATS = %w[rb json yml yaml].freeze

      # Sets up the credentials and initializes the Jenkins Pipeline Builder
      #
      # @param [Hash] options Options obtained from the command line
      #
      # @return [JenkinsPipelineBuilder::Generator] A new Client object
      #
      def self.setup(options)
        process_creds options

        JenkinsPipelineBuilder.credentials = jenkins_api_creds
        generator = JenkinsPipelineBuilder.generator
        JenkinsPipelineBuilder.debug! if options[:debug]
        generator
      end

      def self.process_creds(options)
        default_file = find_default_file
        if options[:debug]
          self.jenkins_api_creds = { username: :foo, password: :bar, server_ip: :baz }
        elsif valid_cli_creds? options
          process_cli_creds(options)
        elsif options[:creds_file]
          process_creds_file options[:creds_file]
        elsif default_file
          process_creds_file default_file
        else
          msg = 'Credentials are not set. Please pass them as parameters or'
          msg << ' set them in the default credentials file'
          warn msg
          exit 1
        end
      end

      def self.valid_cli_creds?(options)
        options[:username] && options[:server] && (options[:password] || options[:password_base64])
      end

      def self.process_creds_file(file)
        return load File.expand_path(file) if file.end_with? 'rb'
        return self.jenkins_api_creds = JSON.parse(IO.read(File.expand_path(file))) if file.end_with? 'json'

        self.jenkins_api_creds = YAML.load_file(File.expand_path(file))
      end

      def self.process_cli_creds(options)
        self.jenkins_api_creds = {}.with_indifferent_access.merge options
        if jenkins_api_creds[:server] =~ Resolv::AddressRegex
          jenkins_api_creds[:server_ip] = jenkins_api_creds.delete :server
        elsif jenkins_api_creds[:server] =~ URI::DEFAULT_PARSER.make_regexp
          jenkins_api_creds[:server_url] = jenkins_api_creds.delete :server
        else
          msg = "server given (#{jenkins_api_creds[:server]}) is neither a URL nor an IP."
          msg << ' Please pass either a valid IP address or valid URI'
          warn msg
          exit 1
        end
      end

      def self.find_default_file
        default_file_name = "#{ENV['HOME']}/.jenkins_api_client/login"

        found_suffix = nil
        DEFAULT_FILE_FORMATS.each do |suffix|
          next unless File.exist?("#{default_file_name}.#{suffix}")

          if !found_suffix
            found_suffix = suffix
          else
            logger.warn "Multiple default files found! Using '#{default_file_name}.#{found_suffix}' but \
'#{default_file_name}.#{suffix}' found."
          end
        end
        "#{ENV['HOME']}/.jenkins_api_client/login.#{found_suffix}" if found_suffix
      end

      def self.logger
        JenkinsPipelineBuilder.logger
      end
      private_class_method :find_default_file, :logger
    end
  end
end
