class Maven3Helper < ExtensionHelper
  def initialize(params, builder)
    super params, builder, defaults
  end

  def defaults
    {
      mavenName: 'tools-maven-3.0.3'
    }
  end
end
