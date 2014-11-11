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
        if options[:username] && options[:server_ip] && \
          (options[:password] || options[:password_base64])
          creds = options
        elsif options[:creds_file]
          if options[:creds_file].end_with? 'json'
            creds = JSON.parse(IO.read(File.expand_path(options[:creds_file])))
          else
            creds = YAML.load_file(File.expand_path(options[:creds_file]))
          end
        elsif File.exist?("#{ENV['HOME']}/.jenkins_api_client/login.yml")
          creds = YAML.load_file(
            File.expand_path("#{ENV['HOME']}/.jenkins_api_client/login.yml", __FILE__)
          )
        elsif options[:debug]
          creds = { username: :foo, password: :bar, server_ip: :baz }
        else
          msg = 'Credentials are not set. Please pass them as parameters or'
          msg << ' set them in the default credentials file'
          puts msg
          exit 1
        end

        JenkinsPipelineBuilder.credentials = creds
        generator = JenkinsPipelineBuilder.generator
        generator.debug = options[:debug]
        generator
      end
    end
  end
end
