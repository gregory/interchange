require "interchange/version"

class Interchange < Module
  class UnregisteredError < StandardError
    def initialize(name)
      super "#{name} is not a registered implementation"
    end
  end

  class ImplementationMissingError < StandardError
    def initialize(object, method)
      super "The #{object.class} does not respond to #{method}"
    end
  end

  class NotAvailableError < StandardError
    def initialize(implementation)
      super "#{implementation} currently down"
    end
  end

  class NullImplementation
    def up?
      true
    end

    def respond_to?(*args)
      true
    end

    def method_missing(name, *args, &block)
      args
    end
  end

  class DownImplementation < NullImplementation
    def up?
      false
    end
  end

  module Methods
    def register(name, implementation)
      implementations[name] = implementation
    end

    def use(name)
      @implementation = implementations.fetch name do
        raise UnregisteredError, name
      end
    end

    def with(name)
      original = implementation
      use name
      result = yield self
      @implementation = original

      result
    end

    def down?
      !up?
    end

    def check
      fail NotAvailableError, implementation unless up?
      true
    end

    def implementations
      @implementations ||= { }
    end

    def implementation
      @implementation
    end
  end

  module DefaultImplementationsForInstances
    def initialize(*args)
      super
      register :null, NullImplementation.new
      register :down, DownImplementation.new
      use :null
    end
  end

  def included(base)
    base.send :include, DefaultImplementationsForInstances
  end

  def extended(klass)
    klass.register :null, NullImplementation.new
    klass.register :down, DownImplementation.new
    klass.use :null
  end

  def initialize(*methods)
    module_eval do
      include Methods
    end

    define_delegate_method :up?

    methods.each do |method|
      define_delegate_method method
    end
  end

  def define_delegate_method(method)
    define_method method do |*args, &block|
      raise ImplementationMissingError.new(implementation, method) unless implementation.respond_to? method
      implementation.send method, *args, &block
    end
  end
end
