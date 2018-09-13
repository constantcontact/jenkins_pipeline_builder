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
  class Promotion
    def initialize(generator)
      @generator = generator
      @client = generator.client
      @logger = @client.logger
    end

    def create(params, job_name)
      success, payload = prom_to_xml(params)
      return success, payload unless success

      xml = payload
      return local_output(xml) if JenkinsPipelineBuilder.debug || JenkinsPipelineBuilder.file_mode

      @client.get_config(get_process_path(job_name, params[:name]))
      @client.post_config(set_process_path(job_name, params[:name]), xml)
    rescue JenkinsApi::Exceptions::NotFound
      @client.post_config(init_process_path(job_name, params[:name]), xml)
    end

    def prom_to_xml(params)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.send('hudson.plugins.promoted__builds.PromotionProcess', 'plugin' => 'promoted-builds@2.27') do
          xml.buildSteps
          xml.conditions
        end
      end
      @n_xml = builder.doc
      JenkinsPipelineBuilder.registry.traverse_registry_path('job', params, @n_xml)
      [true, @n_xml.to_xml]
    end

    def local_output(xml)
      JenkinsPipelineBuilder.logger.info 'Will create promotion'
      JenkinsPipelineBuilder.logger.info xml.to_s if @debug
      xml.to_s if @debug
      FileUtils.mkdir_p(out_dir) unless File.exist?(out_dir)
      File.open("#{out_dir}/promotion_debug.xml", 'w') { |f| f.write xml }
      xml
    end

    def out_dir
      'out/xml'
    end

    private

    def init_process_path(job_name, process_name)
      "/job/#{URI.encode job_name}/promotion/createProcess?name=#{URI.encode process_name}"
    end

    def set_process_path(job_name, process_name)
      "/job/#{URI.encode job_name}/promotion/process/#{URI.encode process_name}/config.xml"
    end

    def get_process_path(job_name, process_name)
      "/job/#{URI.encode job_name}/promotion/process/#{URI.encode process_name}"
    end
  end
end
