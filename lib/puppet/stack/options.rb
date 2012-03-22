require 'puppet/stack'
#
# This module holds the method that can be used
# to create options that are shared between face actions
#
module Puppet::Stack::Options
  # methods to add options
  def self.add_option_name(action)
    action.option '--name=' do
      summary 'identifier that refers to the specified deployment'
      required
    end
  end

  def self.add_option_config(action)
    action.option '--config=' do
      summary 'Config file used to specify the multi node deployment to build'
      description <<-EOT
      Config file used to specficy how to build out stacks of nodes.
      EOT
      required
    end
  end
end
