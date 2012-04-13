require 'puppet/face'
require 'puppet/stack'
require 'puppet/stack/options'
Puppet::Face.define(:stack, '0.0.1') do
  summary 'Face for building out multi-node deployments'

  action :build do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Build nodes in stack config and perform create, install, test action.'
    description <<-EOT
Provide a stack config file to build a collection of nodes. This action will
perform create, install, and test action. Create provisioning process occurs in
parallel while the rest of the action is done in sequence.
    EOT
    when_invoked do |options|
      Puppet::Stack.build(options)
      # TODO this should return a hash that represents all of the things that
      # were built
    end
  end

  action :connect do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Establish connection to all of the nodes in the stack via tmux.'
    when_invoked do |options|
      Puppet::Stack.tmux(options)
    end
  end

  action :create do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Create a group of node(s) specified in stack configuration.'
    description <<-EOT
Create a group of node(s) as specified in stack configuration. Stack builder
assume the nodes exist if there are no create action.
    EOT
    when_invoked do |options|
      Puppet.fail('Create is not yet implemented')
    end
  end

  action :destroy do
    Puppet::Stack::Options.add_option_name(self)
    summary 'Destroy a group of node(s) created by stack builder.'
    description <<-EOT
Destroy a group of nodes created by stack builder. The stacks are tracked in
puppet[:confdir]/stack/ as they are created and destroyed. If the nodes are not
created by stack builder, they will not be destroyed by this action.
    EOT
    when_invoked do |options|
      Puppet::Stack.destroy(options)
    end
  end

  action :install do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Performs install action for a group of node(s) in stack configuration.'
    description <<-EOT
Performs the specified install actions for a nodes.  Assumes the nodes have
already been created and does not need provisioning.
    EOT
    when_invoked do |options|
      Puppet.fail('Install is not yet implemented')
    end
    when_rendering :console do |value|
      value.inspect  if value
    end
  end

  action :test do
    Puppet::Stack::Options.add_option_name(self)
    Puppet::Stack::Options.add_option_config(self)
    summary 'Perfom test action for a group of node(s) in stack configuration.'
    description <<-EOT
Runs the specified test action for a stack.  Assumes that the stack has already
been created.
    EOT
    when_invoked do |options|
      Puppet.fail('Test is not yet implemented')
    end
  end

  action :list do
    when_invoked do |options|
      Puppet::Stack.list(options)
    end
    summary 'List stacks created by stack builder.'
    when_rendering :console do |value|
      value.collect do |id, status_hash|
        "#{id}:\n" + status_hash.collect do |field, val|
          "  #{field}: #{val.inspect}"
        end.sort.join("\n")
      end.sort.join("\n")
    end
  end

end
