require File.expand_path('../spec_helper', __FILE__)

describe 'Compiler' do
  it 'transforms hash into hash' do
    hash = {
        a: 'A sentence',
        b: 'B sentence',
        hash: {
            c: 5,
            d: true
        },
        z: false
    }

    success, result = JenkinsPipelineBuilder::Compiler.compile(hash)

    expect(success).to be_true
    result.should == hash
  end
end
