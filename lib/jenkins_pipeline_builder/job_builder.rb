#
# Copyright (c) 2014 Igor Moochnick
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

module JenkinsPipelineBuilder
  class JobBuilder
    def self.change_description(description, n_xml)
      desc = n_xml.xpath("//description").first
      desc.content = "#{description}"
    end

    def self.apply_scm_params(params, n_xml)
      XmlHelper.update_node_text(n_xml, '//scm/localBranch', params[:local_branch]) if params[:local_branch]
      XmlHelper.update_node_text(n_xml, '//scm/recursiveSubmodules', params[:recursive_update]) if params[:recursive_update]
      XmlHelper.update_node_text(n_xml, '//scm/wipeOutWorkspace', params[:wipe_workspace]) if params[:wipe_workspace]
      XmlHelper.update_node_text(n_xml, '//scm/excludedUsers', params[:excluded_users]) if params[:excluded_users]
      XmlHelper.update_node_text(n_xml, '//scm/userRemoteConfigs/hudson.plugins.git.UserRemoteConfig/name', params[:remote_name]) if params[:remote_name]
    end

    def self.hipchat_notifier(params, n_xml)
      raise "No HipChat room specified" unless params[:room]

      properties = n_xml.xpath("//properties").first
      Nokogiri::XML::Builder.with(properties) do |xml|
        xml.send('jenkins.plugins.hipchat.HipChatNotifier_-HipChatJobProperty') {
          xml.room params[:room]
          xml.startNotification params[:'start-notify'] || false
        }
      end
    end

    def self.build_parameters(params, n_xml)
      n_builders = n_xml.xpath('//properties').first
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        xml.send('hudson.model.ParametersDefinitionProperty') {
          xml.parameterDefinitions {
            param_proc = lambda do |xml, name, type, default, description|
              xml.send(type) {
                xml.name name
                xml.description description
                xml.defaultValue default
              }
            end
            params.each do |param|
              case param[:type]
                when 'string'
                  paramType = 'hudson.model.StringParameterDefinition'
                when 'bool'
                  paramType = 'hudson.model.BooleanParameterDefinition'
                when 'text'
                  paramType = 'hudson.model.TextParameterDefinition'
                when 'password'
                  paramType = 'hudson.model.PasswordParameterDefinition'
                else
                  paramType = 'hudson.model.StringParameterDefinition'
              end

              param_proc.call xml, param[:name], paramType, param[:default], param[:description]
            end
          }
        }
      end
    end

    def self.discard_old_param(params, n_xml)
      properties = n_xml.child
      Nokogiri::XML::Builder.with(properties) do |xml|
        xml.send('logRotator', 'class' => 'hudson.tasks.LogRotator') {
          xml.daysToKeep params[:days] if params[:days]
          xml.numToKeep params[:number] || -1
          xml.artifactDaysToKeep params[:artifact_days] || -1
          xml.artifactNumToKeep params[:artifact_number] || -1
        }
      end
    end
  end
end
