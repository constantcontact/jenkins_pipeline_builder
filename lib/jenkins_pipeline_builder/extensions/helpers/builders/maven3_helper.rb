class Maven3Helper < ExtensionHelper
  def initialize(extension, params, builder)
    super extension, params, builder, defaults
  end

  def defaults
    {
      mavenName: 'tools-maven-3.0.3'
    }
  end
end
