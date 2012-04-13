# Overview

Stack builder is a tool for building stacks of systems using Puppet Cloud Provisioner tool. This project is an experimental prototype so expect changes.

# Installation and configuration

## EC2 Account

Create EC2 account.
Create keypair in appropriate EC2 region.
Create the following security groups:

* default: TCP 22, icmp all.
* puppetmaster: TCP 443, TCP 8140.

## Puppet

Install the latest version of puppet from apt.puppetlabs.com or yum.puppetlabs.com or use envpuppet script to run from source.

## Puppet Cloud Provisioner

Stack builder requires [Puppet Cloud Provisioner](https://github.com/puppetlabs/puppetlabs-cloud-provisioner). Cloud Provisioner with VMware support can be obtained by installing Puppet Enterprise 2.0+.

The following instructions are for users using cloud provisioner from source. For users of forge.puppetlabs.com module see [getting started documentation](http://docs.puppetlabs.com/guides/cloud_pack_getting_started.html), for Puppet Enterprise users see [cloud provisioning documentation](http://docs.puppetlabs.com/pe/2.0/cloudprovisioner_overview.html).

Install ruby and rubygems:

    apt-get install ruby rubygems
    yum install ruby rubygems

Install guid and fog ruby gems:

    gem install guid
    gem install fog

Git clone puppet cloud provisioner and add its lib directory to RUBYLIB

    mkdir ~/src/
    cd ~/src/
    git clone https://github.com/puppetlabs/puppetlabs-cloud-provisioner
    export RUBYLIB=~/src/puppetlabs-cloud-provisioner/lib:$RUBYLIB

Configure fog credentials in ~/.fog:

    :default:
      :aws_access_key_id: ...
      :aws_secret_access_key: ...

Verify cloud provisioner Puppet face is loaded and working:

    puppet help node_aws

## Install stack builder

Git clone stack deployer and add its lib directory to RUBYLIB

    cd ~/src
    git clone https://github.com/bodepd/stack_builder
    export RUBYLIB=~/src/stack_builder/lib:$RUBYLIB

Verify stack_builder Puppet face is loaded and working:

    puppet help stack

## Configuration

Stack builder supports default setting in Puppet[:confdir]/stack_builder.yaml (puppet agent --configprint confdir).

    create:
      options:
        keyname: stack_keys
        type: m1.small
        region: us-west-2
        image: ami-06c54936
        group: default
    install:
      options:
        keyfile: ~/.ssh/stack_keys.pem
        login: ubuntu

# Usage

stack builder supports the following action:

    build      Build nodes in stack by performing create, install, test action.
    connect    Establish connection to all nodes in the stack via tmux.
    create     Create a nodes specified in stack configuration.
    destroy    Destroy nodes created by stack builder.
    install    Performs install action for nodes in stack configuration.
    list       List stacks created by stack_builder.
    test       Performs test action for nodes in stack configuration.

## Example

Create a 4 node openstack swift stack:

    puppet stack build --name demo_stack --config config/swift/oneiric_swift_multi

Connect to swift stack:

    puppet stack connect --name demo_stack --config config/swift/oneiric_swift_multi

Destroy swift stack:

    puppet stack destroy --name demo_stack

## Working AMI

us-east-1:

* Ubuntu Oneric: ami-a0ba68c9 (i386), ami-baba68d3 (x86_64)
* Fedora 16: ami-5f16d836 (i386), ami-0316d86a (x86_64)

- I would like to be able to specify a master from a different file
