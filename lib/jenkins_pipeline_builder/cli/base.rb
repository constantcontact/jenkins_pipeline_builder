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

require 'thor'

module JenkinsPipelineBuilder
  module CLI
    class Base < Thor
      class_option :username, aliases:  '-u', desc:  'Name of Jenkins user'
      class_option :password, aliases:  '-p', desc:  'Password of Jenkins user'
      class_option :password_base64, aliases:  '-b', desc:  'Base 64 encoded password of Jenkins user'
      class_option :server_ip, aliases:  '-s', desc:  'Jenkins server IP address'
      class_option :server_port, aliases:  '-o', desc:  'Jenkins port'
      class_option :creds_file, aliases:  '-c', desc:  'Credentials file for communicating with Jenkins server'
      class_option :debug, type:  :boolean, aliases:  '-d', desc:  'Run in debug mode (no Jenkins changes)', default:  false

      map '-v' => :version

      desc 'version', 'Shows current version'
      # CLI command that returns the version of Jenkins API Client
      def version
        puts JenkinsPipelineBuilder::VERSION
      end

      desc 'pipeline [subcommand]', 'Provides functions to access pipeline functions of the Jenkins CI server'
      subcommand 'pipeline', CLI::Pipeline

      desc 'view [subcommand]', 'Provides functions to access view interface of Jenkins CI server'
      subcommand 'view', CLI::View

      desc 'list [type]', 'Lists all registered modules of a type'
      subcommand 'list', List

      desc 'describe [type]', 'Describe a module'
      subcommand 'describe', Describe
    end
  end
end
