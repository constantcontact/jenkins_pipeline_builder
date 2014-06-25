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

module JenkinsPipelineBuilder
  class Wrappers < Extendable
    register :ansicolor, jenkins_name: 'color ansi', description: 'this is a description' do |_, xml|
      xml.send('hudson.plugins.ansicolor.AnsiColorBuildWrapper') do
        xml.colorMapName 'xterm'
      end
    end

    register :timestamp do |_, xml|
      xml.send('hudson.plugins.timestamper.TimestamperBuildWrapper', 'plugin' => 'timestamper')
    end

    register :rvm05 do |wrapper, xml|
      xml.send('ruby-proxy-object') do
        xml.send('ruby-object', 'ruby-class' => 'Jenkins::Tasks::BuildWrapperProxy', 'pluginid' => 'rvm') do
          xml.object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
            xml.impl('pluginid' => 'rvm', 'ruby-class' => 'String') { xml.text wrapper }
          end
          xml.pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { xml.text 'rvm' }
        end
      end
    end

    register :rvm do |wrapper, xml|
      xml.send('ruby-proxy-object') do
        xml.send('ruby-object', 'ruby-class' => 'Jenkins::Plugin::Proxies::BuildWrapper', 'pluginid' => 'rvm') do
          xml.object('ruby-class' => 'RvmWrapper', 'pluginid' => 'rvm') do
            xml.impl('pluginid' => 'rvm', 'ruby-class' => 'String') { xml.text wrapper }
          end
          xml.pluginid(:pluginid => 'rvm', 'ruby-class' => 'String') { xml.text 'rvm' }
        end
      end
    end

    register :inject_passwords do |passwords, xml|
      xml.EnvInjectPasswordWrapper do
        xml.injectGlobalPasswords false
        xml.passwordEntries do
          passwords.each do |password|
            xml.EnvInjectPasswordEntry do
              xml.name password[:name]
              xml.value password[:value]
            end
          end
        end
      end
    end

    register :inject_env_var do |params, xml|
      xml.EnvInjectBuildWrapper do
        xml.info do
          xml.propertiesFilePath params[:file] if params[:file]
          xml.propertiesContent params[:content] if params[:content]
          xml.loadFilesFromMaster false
        end
      end
    end

    register :artifactory do |wrapper, xml|
      xml.send('org.jfrog.hudson.generic.ArtifactoryGenericConfigurator') do
        xml.details do
          xml.artifactoryUrl wrapper[:url]
          xml.artifactoryName wrapper[:'artifactory-name']
          xml.repositoryKey wrapper[:'release-repo']
          xml.snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
        end
        xml.deployPattern wrapper[:publish]
        xml.resolvePattern
        xml.matrixParams wrapper[:properties]
        xml.deployBuildInfo wrapper[:'publish-build-info']
        xml.includeEnvVars false
        xml.envVarsPatterns do
          xml.includePatterns
          xml.excludePatterns '*password*,*secret*'
        end
        xml.discardOldBuilds false
        xml.discardBuildArtifacts true
      end
    end

    register :maven3artifactory do |wrapper, xml|
      xml.send('org.jfrog.hudson.maven3.ArtifactoryMaven3Configurator') do # plugin='artifactory@2.2.1'
        xml.details do
          xml.artifactoryUrl wrapper[:url]
          xml.artifactoryName wrapper[:'artifactory-name']
          xml.repositoryKey wrapper[:'release-repo']
          xml.snapshotsRepositoryKey wrapper.fetch(:'snapshot-repo', wrapper[:'release-repo'])
        end
        xml.deployArtifacts wrapper.fetch(:'deploy', true)
        xml.artifactDeploymentPatterns do
          xml.includePatterns
          xml.excludePatterns
        end
        xml.includeEnvVars false
        xml.deployBuildInfo wrapper.fetch(:'publish-build-info', true)
        xml.envVarsPatterns do
          xml.includePatterns
          xml.excludePatterns '*password*,*secret*'
        end
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
      end
    end
  end
end
