require File.expand_path('../spec_helper', __FILE__)

describe 'ModuleRegistry' do

  it 'should return item by a specified path' do

    registry = JenkinsPipelineBuilder::ModuleRegistry.new(
      zz: {
        aa: 'aa',
        bb: 'bb',
        cc: {
          dd: 'dd'
        }
      }
    )

    registry.get('zz/aa').should be == 'aa'
  end
end
