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
  class Wrappers
    def self.ansicolor(wrapper, xml)
      xml.send('hudson.plugins.ansicolor.AnsiColorBuildWrapper') {
        xml.colorMapName 'xterm'
      }
    end

    def self.console_timestamp(wrapper, xml)
      xml.send('hudson.plugins.timestamper.TimestamperBuildWrapper', 'plugin' => 'timestamper')
    end

    def self.run_with_rvm05(wrapper, xml)
      xml.send('ruby-proxy-object') {
        xml.send('ruby-object', 'ruby-class' => 'Jenkins::Tasks::BuildWrapperProxy', 'pluginid' => 'rvm') {
          xml.object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') {
            xml.impl('pluginid' => "rvm", 'ruby-class' => 'String') { xml.text wrapper }
          }
          xml.pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { xml.text 'rvm' }
        }
      }
    end
    def self.run_with_rvm(wrapper, xml)
      xml.send('ruby-proxy-object') {
        xml.send('ruby-object', 'ruby-class' => 'Jenkins::Plugin::Proxies::BuildWrapper', 'pluginid' => 'rvm') {
          xml.object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') {
            xml.impl('pluginid' => "rvm", 'ruby-class' => 'String') { xml.text wrapper }
          }
          xml.pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { xml.text 'rvm' }
        }
      }
    end

    def self.inject_passwords(passwords, xml)
      xml.EnvInjectPasswordWrapper {
        xml.injectGlobalPasswords false
        xml.passwordEntries {
          passwords.each do |password|
            xml.EnvInjectPasswordEntry {
              xml.name password[:name]
              xml.value password[:value]
            }
          end
        }
      }
    end

    def self.inject_env_vars(params, xml)
      xml.EnvInjectBuildWrapper {
        xml.info {
          xml.propertiesFilePath params[:file] if params[:file]
          xml.propertiesContent params[:content] if params[:content]
          xml.loadFilesFromMaster false
        }
      }
    end

    def self.publish_to_artifactory(wrapper, xml)
      xml.send('org.jfrog.hudson.generic.ArtifactoryGenericConfigurator') {
        xml.details {
          xml.artifactoryUrl wrapper[:url]
          xml.artifactoryName wrapper[:'artifactory-name']
          xml.repositoryKey wrapper[:'release-repo']
          xml.snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
        }
        xml.deployPattern wrapper[:publish]
        xml.resolvePattern
        xml.matrixParams
        xml.deployBuildInfo wrapper[:'publish-build-info']
        xml.includeEnvVars false
        xml.envVarsPatterns {
          xml.includePatterns
          xml.excludePatterns '*password*,*secret*'
        }
        xml.discardOldBuilds false
        xml.discardBuildArtifacts true
      }
    end

    def self.artifactory_maven3_configurator(wrapper, xml)
      xml.send('org.jfrog.hudson.maven3.ArtifactoryMaven3Configurator') { # plugin="artifactory@2.2.1"
        xml.details {
          xml.artifactoryUrl wrapper[:url]
          xml.artifactoryName wrapper[:'artifactory-name']
          xml.repositoryKey wrapper[:'release-repo']
          xml.snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
        }
        xml.deployArtifacts wrapper.fetch(:'deploy', true)
        xml.artifactDeploymentPatterns {
          xml.includePatterns
          xml.excludePatterns
        }
        xml.includeEnvVars false
        xml.deployBuildInfo wrapper.fetch(:'publish-build-info', true)
        xml.envVarsPatterns {
          xml.includePatterns
          xml.excludePatterns '*password*,*secret*'
        }
        xml.runChecks false
        xml.violationRecipients
        xml.includePublishArtifacts false
        xml.scopes
        xml.licenseAutoDiscovery true
        xml.disableLicenseAutoDiscovery false
        xml.discardOldBuilds false
        xml.discardBuildArtifacts true
        xml.matrixParams
        xml.enableIssueTrackerIntegration false
        xml.aggregateBuildIssues false
        xml.blackDuckRunChecks false
        xml.blackDuckAppName
        xml.blackDuckAppVersion
        xml.blackDuckReportRecipients
        xml.blackDuckScopes
        xml.blackDuckIncludePublishedArtifacts false
        xml.autoCreateMissingComponentRequests true
        xml.autoDiscardStaleComponentRequests true
        xml.filterExcludedArtifactsFromBuild false
      }
    end
  end
end
