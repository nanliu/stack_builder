require 'puppet/face'
require 'puppet/stack'
require 'puppet/stack/options'
Puppet::Face.define(:stack, '0.0.1') do
  summary 'Face for building out multi-node deployments'

  action :create do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Create a group of specified nodes to form a stack'
    when_invoked do |options|
      Puppet.fail('Create is not yet implemented')
    end
  end

  action :install do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'runs the specified install actions for a stack'
    description <<-EOT
    Runs the specified install actions for a nodes.
    Assumes that the stack has already been created.
    EOT
    when_invoked do |options|
      Puppet.fail('Install is not yet implemented')
    end
  end

  action :test do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'runs the specified integration tests'
    description <<-EOT
    Runs the specified test action for a stack.
    Assumes that the stack has already been created.
    EOT
    when_invoked do |options|
      Puppet.fail('Test is not yet implemented')
    end
  end

  action :build do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
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
    Puppet::Stack::Options.add_option_name(self)
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
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'connect to all of the nodes in the stack via tmux'
    when_invoked do |options|
      Puppet::Stack.tmux(options)
    end
  end

end
