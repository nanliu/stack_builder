require 'puppet/face'
require 'puppet/stack'
Puppet::Face.define(:stack, '0.0.1') do
  summary 'Face for building out multi-node deployments'

  option '--config=' do
    summary 'Config file used to specify the multi node deployment to build'
    description <<-EOT
    Config file used to specficy how to build out stacks of nodes.
    EOT
    required
  end
  option '--name=' do
    summary 'identifier that refers to the specified deployment'
    required
  end

  action :create do
    summary 'Just create a group of specified nodes'
    when_invoked do |options|
      Puppet.fail('Create is not yet implemented')
    end
  end

  action :build do
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

  action :provision do
    when_invoked do |options|
      Puppet::Stack.provision(options)
    end
  end

end
