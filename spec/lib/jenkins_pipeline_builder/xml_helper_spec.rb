require File.expand_path('../spec_helper', __FILE__)

describe JenkinsPipelineBuilder::XmlHelper do
  let(:xml_helper) { JenkinsPipelineBuilder::XmlHelper }
  let(:xml_sample) { '<?xml version="1.0" encoding="UTF-8"?><project><actions/><description/><keepDependencies>false</keepDependencies><scm class="hudson.scm.NullSCM"/><canRoam>true</canRoam><concurrentBuild>false</concurrentBuild></project>' }
  let(:n_xml) { n_xml = Nokogiri::XML(xml_sample) }
  describe '#self.update_node_text' do
    it 'found node and updated it' do
      xml_helper.update_node_text(n_xml, '//canRoam', false)
      expect(n_xml.xpath('//canRoam').to_s).to eq('<canRoam>false</canRoam>')
    end
    it 'test an invalid path' do
      xml_helper.update_node_text(n_xml, '//actions/newThing', true)
      expect(n_xml.xpath('//actions/newThing').to_s).to eq('<newThing>true</newThing>')
    end
  end
end
