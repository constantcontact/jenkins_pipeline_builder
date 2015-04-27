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

module JenkinsPipelineBuilder
  module CLI
    # This is the helper class that sets up the credentials from the command
    # line parameters given and initializes the Jenkins Pipeline Builder.
    class Helper
      # Sets up the credentials and initializes the Jenkins Pipeline Builder
      #
      # @param [Hash] options Options obtained from the command line
      #
      # @return [JenkinsPipelineBuilder::Generator] A new Client object
      #
      def self.setup(options)
        creds = process_creds options

        JenkinsPipelineBuilder.credentials = creds
        generator = JenkinsPipelineBuilder.generator
        JenkinsPipelineBuilder.debug! if options[:debug]
        generator
      end

      def self.process_creds(options)
        if valid_cli_creds? options
          process_cli_creds(options)
        elsif options[:creds_file]
          process_creds_file options[:creds_file]
        elsif File.exist?("#{ENV['HOME']}/.jenkins_api_client/login.yml")
          YAML.load_file(File.expand_path("#{ENV['HOME']}/.jenkins_api_client/login.yml", __FILE__))
        elsif options[:debug]
          { username: :foo, password: :bar, server_ip: :baz }
        else
          msg = 'Credentials are not set. Please pass them as parameters or'
          msg << ' set them in the default credentials file'
          $stderr.puts msg
          exit 1
        end
      end

      def self.valid_cli_creds?(options)
        options[:username] && options[:server] && (options[:password] || options[:password_base64])
      end

      def self.process_creds_file(file)
        if file.end_with? 'json'
          return JSON.parse(IO.read(File.expand_path(file)))
        else
          return YAML.load_file(File.expand_path(file))
        end
      end

      def self.process_cli_creds(options)
        creds = {}.with_indifferent_access.merge options
        if creds[:server] =~ Resolv::AddressRegex
          creds[:server_ip] = creds.delete :server
        elsif creds[:server] =~ URI.regexp
          creds[:server_url] = creds.delete :server
        else
          msg = "server given (#{creds[:server]}) is neither a URL nor an IP."
          msg << ' Please pass either a valid IP address or valid URI'
          $stderr.puts msg
          exit 1
        end
        creds
      end
    end
  end
end
