require 'puppet/face'
require 'puppet/stack'
Puppet::Face.define(:stack, '0.0.1') do
  summary 'Face for building out multi-node deployments'


  action :create do
    summary 'Just create a group of specified nodes'
    when_invoked do |options|
      Puppet.fail('Create is not yet implemented')
    end
  end

  action :build do
    option '--name=' do
      summary 'identifier that refers to the specified deployment'
      required
    end
    option '--config=' do
      summary 'Config file used to specify the multi node deployment to build'
      description <<-EOT
      Config file used to specficy how to build out stacks of nodes.
      EOT
      required
    end
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
    option '--name=' do
      summary 'identifier that refers to the specified deployment'
      required
    end
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

  action :open_screens do
    option '--name=' do
      summary 'identifier that refers to the specified deployment'
      required
    end
    when_invoked do |options|
      puts 'Not impleneted yet'
    end
  end

end
