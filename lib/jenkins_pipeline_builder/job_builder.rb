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
      XmlHelper.update_node_text(n_xml, '//scm/skipTag', params[:skip_tag]) if params[:skip_tag]
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

    def self.use_specific_priority(params, n_xml)
      n_builders = n_xml.xpath('//properties').first
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        xml.send('jenkins.advancedqueue.AdvancedQueueSorterJobProperty', 'plugin' => 'PrioritySorter') {
          xml.useJobPriority params[:use_priority]
          xml.priority params[:job_priority] || -1
        }
      end
    end

    def self.build_parameters(params, n_xml)
      n_builders = n_xml.xpath('//properties').first
      Nokogiri::XML::Builder.with(n_builders) do |xml|
        xml.send('hudson.model.ParametersDefinitionProperty') {
          xml.parameterDefinitions {
            param_proc = lambda do |xml, params, type|
              xml.send(type) {
                xml.name params[:name]
                xml.description params[:description]
                xml.defaultValue params[:default]
                if params[:type] == 'choice'
                  puts 'choice'
                  puts params
                  xml.choices('class' => 'java.util.Arrays$ArrayList') {
                    xml.a('class' => 'string-array') {
                      params[:values].each do |value|
                        xml.string value
                      end
                    }
                  }
                end
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
                when 'choice'
                  paramType = 'hudson.model.ChoiceParameterDefinition'
                else
                  paramType = 'hudson.model.StringParameterDefinition'
                end

              param_proc.call xml, param, paramType
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

    def self.throttle_job(params, n_xml)
      properties = n_xml.xpath('//properties').first
      cat_set = params[:option]=="category"
      Nokogiri::XML::Builder.with(properties) do |xml|
        xml.send('hudson.plugins.throttleconcurrents.ThrottleJobProperty', 'plugin' => 'throttle-concurrents') {
          xml.maxConcurrentPerNode params[:max_per_node] || 0
          xml.maxConcurrentTotal params[:max_total] || 0
          xml.throttleEnabled true
          xml.throttleOption params[:option] || "alone"
          xml.categories {
            xml.string params[:category] if cat_set
          }
        }
      end
    end

    def self.prepare_environment(params, n_xml)
      properties = n_xml.xpath('//properties').first
      Nokogiri::XML::Builder.with(properties) do |xml|
        xml.send('EnvInjectJobProperty') {
          xml.info{
            xml.propertiesContent params[:properties_content] if params[:properties_content]
            xml.loadFilesFromMaster params[:load_from_master] if params[:load_from_master]
          }
          xml.on true
          xml.keepJenkinsSystemVariables params[:keep_environment] if params[:keep_environment]
          xml.keepBuildVariables params[:keep_build] if params[:keep_build]
        }
      end
    end

    def self.concurrent_build(params, n_xml)
      concurrentBuild = n_xml.xpath('//concurrentBuild').first
      concurrentBuild.content = (params == true) ? 'true' : 'false'
    end

  end
end
