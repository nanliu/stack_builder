# Installation

create EC2 account.
create keypair in appropriate EC2 region.
create the following security groups:

* default: 80 open icmp all, tcp 22
* puppetmaster: open tcp 8140

ensure that rubygems are installed (apt-get install rubygems)

install the latest version of puppet (2.7.12) from apt.puppetlabs.com

install puppet cloud provisioner and add its lib directory to RUBYLIB

    mkdir ~/dev/
    cd ~/dev/
    git clone https://github.com/puppetlabs/puppetlabs-cloud-provisioner
    export RUBYLIB=~/dev/puppetlabs-cloud-provisioner/lib:$RUBYLIB

install stack deployer and add its lib directory to RUBYLIB

    cd ~/dev
    git clone https://github.com/bodepd/stack_builder
    export RUBYLIB=~/stack_builder/lib:$RUBYLIB

gem install guid
gem install fog
configure fog credentials in ~/.fog:

    :default:
      :aws_access_key_id: ...
      :aws_secret_access_key: ...

verify everything is working:

* verify cloud provisioner:

        puppet help node_aws

* verify stack_builder:

        puppet help stack

This should build a 4 node swift cluster:

    puppet stack build --name dans_stack --config config/oneiric_swift_multi  --trace

# Working AMI

us-east-1:

* Ubuntu Oneric: ami-a0ba68c9 (i386), ami-baba68d3 (x86_64)
* Fedora 16: ami-5f16d836 (i386), ami-0316d86a (x86_64)



- I would like to be able to specify a master from a different file
