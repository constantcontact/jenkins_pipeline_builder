class ExtensionHelper < SimpleDelegator
  attr_reader :params, :builder
  attr_accessor :extension
  def initialize(params, builder, defaults = {})
    # TODO: We should allow for default values to be passed in here
    # That will allow for defaults to be pulled out of the extension and it
    # will also let better enable overriding of those values that do not have
    # an option to do so currently.
    @params = if params.is_a? Hash
                defaults.merge params
              else
                params
              end
    @builder = builder
    super @params
  end

  def method_missing(name, *args, &block)
    return super unless extension.parameters.include? name
    self[name]
  end

  # TODO: Method missing that pulls out of params?
  # That would allow everything to just call helper.foo
  # and then the helper can do any fiddling it needs to (or not)
end
