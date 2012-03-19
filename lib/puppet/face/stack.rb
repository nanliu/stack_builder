require 'puppet/face'
require 'puppet/stack'
Puppet::Face.define(:stack, '0.0.1') do
  summary 'Face for building out multi-node deployments'


  action :create do
    summary 'Just create a group of specified nodes'
    Puppet::Stack.add_option_name(self)
    Puppet::Stack.add_option_config(self)
    when_invoked do |options|
      Puppet.fail('Create is not yet implemented')
    end
  end

    end
    end
  action :build do
    Puppet::Stack.add_option_name(self)
    Puppet::Stack.add_option_config(self)
    description <<-EOT
     Reads a config file and uses it to build out a collection
     of nodes.
     Build will perform create, install, and test
     It provisions everything in parallel.
    EOT
    when_invoked do |options|
      Puppet::Stack.build(options)
      # TODO this should return a hash that represents all of the things that
      # were built
    end
  end

  action :destroy do
    Puppet::Stack.add_option_name(self)
    when_invoked do |options|
      Puppet::Stack.destroy(options)
    end
  end

  action :list do
    when_invoked do |options|
      Puppet::Stack.list(options)
    end
    # list all of the projects that are being managed
  end

  action :connect do
    Puppet::Stack.add_option_name(self)
    when_invoked do |options|
      puts 'Not impleneted yet'
    end
  end

end
