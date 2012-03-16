require 'puppet'
require 'yaml'
require 'fileutils'
require 'erb'
#
# I would like for this to be a simple config language that does the
# following:
#    if creation blocks are specified for nodes, create them
#    if install blocks are created for nodes, then run scripts
#    via remote ssh
#
# If I add some kind of mounting support, this can be a replacement for
# vagrant
#
# for installation, I should use Nan's code and convert a specified hash
# into class declarations passed in via -e
#
class Puppet::Stack

  def self.build(options)

    stack_file = File.join(get_stack_path, options[:name])
    raise(Puppet::Error, "Stackfile #{stack_file} already exists. Stack names supplied via --name must be unique") if File.exists?(stack_file)
    # TODO I do not want to be setting up logging here
    Puppet::Util::Log.level = :debug
    Puppet::Util::Log.newdestination(:console)
    # parse the nodes that compose the stack
    config = YAML.load_file(options[:config]) || {'nodes' => [], 'master' => {}}
    nodes  = process_config(config)
    puppet_run_type = config['puppet_run_type'] || 'apply'

    # create all nodes that need to be created
    created_master = create_master(nodes['master'])
    # figure out the hostname of the master to connect to
    puppetmaster_hostname = if created_master.size > 0
      created_master.values[0]['hostname']
    elsif nodes['master']
      nodes['master'].keys[0]
    else
      nil
    end

    created_instances =  create_instances(nodes['nodes'])
    # install all nodes that need to be installed
    save(stack_file, {'nodes' => created_instances, 'master' => created_master})
    installed_instances = nodes['nodes'] == {} ? nil :  install_instances(
                                                          nodes['nodes'],
                                                          created_instances,
                                                          puppet_run_type,
                                                          puppetmaster_hostname
                                                        )
    # run tests that need to be run
    test_results = test_instances(nodes['nodes'], created_instances)
  end

  def self.destroy(options)
    destroyed_dir = File.join(get_stack_path, 'destroyed')
    FileUtils.mkdir(destroyed_dir) unless File.directory?(destroyed_dir)
    stack_file = File.join(get_stack_path, options[:name])
    raise(Puppet::Error, "Stackfile for stack to destroy #{stack_file} does not exists. Stack names supplied via --name must have corresponding stack file to be destroyed") unless File.exists?(stack_file)
    stack = YAML.load_file(stack_file)
    unless stack['master'] == {}
      master_hostname = stack['master'].values[0]['hostname'] if stack['master']
      Puppet.notice("Destroying master #{master_hostname}")
      Puppet::Face[:node_aws, :current].terminate(master_hostname, {:region => stack['master'].values[0]['region']})
    end
    stack['nodes'].each do |name, attrs|
      Puppet.notice("Destroying agent #{attrs['hostname']}")
      Puppet::Face[:node_aws, :current].terminate(attrs['hostname'], {:region => attrs['region']})
    end
    FileUtils.mv(stack_file, File.join(destroyed_dir, "#{options[:name]}-#{Time.now.to_i}"))
  end


  def self.list(options)
    Puppet.notice('listing active stacks')
    Dir[File.expand_path("~/.puppet/stacks/*")].each do |file|
      if File.file?(file)
        Puppet.notice("Active stack: #{File.basename(file)}") if File.file?(file)
        puts YAML.load_file(file).inspect
      end
    end
  end

  # TODO I need to add some tests
  def self.create_master(master_node)
    master_only_node = [master_node]
    created_master = create_instances(master_only_node)
    installed_master = install_instances(master_only_node, created_master, 'master')
    created_master
  end

  def self.save(name, stack)
    Puppet.warning('Save has not yet been implememted')
    File.open(name, 'w') do |fh|
      fh.puts(stack.to_yaml)
    end
  end

  # takes a config file and returns a hash of
  # nodes to build
  def self.process_config(config_hash)
    nodes = {}
    master = {}
    creation_defaults = {}
    installation_defaults = {}
    # apply the defaults
    if(config_hash['defaults'])
      Puppet.debug('Getting defaults')
      creation_defaults = config_hash['defaults']['create'] || {}
      installation_defaults = config_hash['defaults']['install'] || {}
    else
      Puppet.debug("No defaults specified")
    end
    if config_hash['master']
      master = config_hash['master']
      raise(Puppet::Error, 'only a single master is supported') if master.size > 1
      master.each do |name, attr|
        if attr
          if master[name].has_key?('create')
            master[name]['create'] ||= {}
            master[name]['create']['options'] = (creation_defaults['options'] || {}).merge(attr['create']['options'] || {})
          end
          if master[name].has_key?('install')
            # TODO I am not yet merging over non-options
            master[name]['install'] ||= {}
            master[name]['install']['options'] = (installation_defaults['options'] || {}).merge(attr['install']['options'] || {})
          end
        end
      end
    end
    if config_hash['nodes']
      nodes = config_hash['nodes']
      nodes.each_index do |index|
        node = nodes[index]
        raise(Puppet::Error, 'Nodes are suposed to be an array of Hashes') unless node.is_a?(Hash)
        # I want to support groups of nodes that can run at the same time
        #raise(Puppet::Error, 'Each node element should be composed of a single hash') unless node.size == 1
        node.each do |name, attr|
          if nodes[index][name].has_key?('create')
            nodes[index][name]['create'] ||= {}
            nodes[index][name]['create']['options'] = (creation_defaults['options'] || {}).merge(attr['create']['options'] || {})
          end
          if nodes[index][name].has_key?('install')
            # TODO I am not yet merging over non-options
            nodes[index][name]['install'] ||= {}
            nodes[index][name]['install']['options'] = (installation_defaults['options'] || {}).merge(attr['install']['options'] || {})
          end
          if nodes[index][name].has_key?('test')
            # the install options are the defaults for test!!!
            nodes[index][name]['test'] ||= {}
            nodes[index][name]['test']['options'] = (installation_defaults['options'] || {}).merge(attr['test']['options'] || {})
          end
        end
      end
    end
    {'nodes' => nodes, 'master' => master}
  end

  # run what ever tests need to be run
  def self.test_instances(nodes, dns_hash)
    # TODO I need to support setting defaults
    nodes.each do |node|
      node.each do |name, attrs|
        hostname = dns_hash[name] ? dns_hash[name]['hostname'] : name
        if attrs['test']
          options = attrs['test']['options']
          require 'puppet/cloudpack'
          Puppet::CloudPack.ssh_remote_execute(
            hostname,
            options['login'],
            attrs['test']['command'],
            options['keyfile']
          )
        end
      end
    end
  end

  # install all of the nodes in order
  def self.install_instances(nodes, dns_hash, puppet_run_type, master = nil)
    begin
      # this setting of confdir sucks
      # I need to patch cloud provisioner to allow arbitrary
      # paths to be set
      old_puppet_dir = Puppet[:confdir]
      stack_dir = get_stack_path
      script_dir = File.join(stack_dir, 'scripts')
      unless File.directory?(script_dir)
        Puppet.info("Creating script directory: #{script_dir}")
        FileUtils.mkdir_p(script_dir)
      end
      Puppet[:confdir] = stack_dir
      nodes.each do |node|
        threads = []
        queue.clear
        # each of these can be done in parallel
        # except can our puppetmaster service simultaneous requests?
        node.each do |name, attrs|
          if attrs and attrs['install']
            Puppet.info("Installing instance #{name}")
            # the hostname is either the node id or the hostname value
            # in the case where we cannot determine the hostname
            hostname = dns_hash[name] ? dns_hash[name]['hostname'] : name
            certname = case(puppet_run_type)
              when 'master' then hostname
              else name
            end
            script_name = script_file_name(hostname)
            # compile our script into a file to perform puppet run
            File.open(File.join(script_dir, "#{script_name}.erb"), 'w') do |fh|
              fh.write(compile_erb(puppet_run_type, attrs['install'].merge('certname' => certname, 'puppetmaster' => master)))
            end
            threads << Thread.new do
              result = install_instance(
                hostname,
                (attrs['install']['options'] || {}).merge(
                  {'install_script' => script_name}
                )
              )
              Puppet.info("Adding instance #{hostname} to queue.")
              queue.push({name => {'result' => result}})
            end
          end
        end
        threads.each do  |aThread|
          begin
            aThread.join
          rescue Exception => spawn_err
            puts("Failed spawning AWS node: #{spawn_err}")
          end
        end
      end
    ensure
      Puppet[:confdir] = old_puppet_dir
    end
  end

  # installation helpers
  # returns the path where install scripts are located
  # this is here in part for mocking out the path where
  # sripts are loaded from
  def self.get_stack_path
    File.expand_path(File.join('~', '.puppet', 'stacks'))
  end

  def self.script_file_name(hostname)
    "#{hostname}-#{Time.now.to_i}"
  end

  def self.compile_erb(name, options)
    ERB.new(File.read(find_template(name))).result(binding)
  end

  def self.find_template(name)
    File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'scripts', "#{name}.erb"))
  end

  # for each of the instances that we need to create
  # spawn a new thread
  def self.create_instances(nodes)
    threads = []
    queue.clear
    nodes.each do |node|
      node.each do |name, attrs|
        if attrs and attrs['create']
          threads << Thread.new do
            Puppet.info("Building instance #{name}")
            # TODO I may want to capture more data when nodes
            # are created
            hostname = create_instance(attrs['create']['options'])
            Puppet.info("Adding instance #{hostname} to queue.")
            queue.push({name => {'hostname' => hostname, 'region' => attrs['create']['options']['region']}})
          end
        end
      end
    end
    threads.each do  |aThread|
      begin
        aThread.join
      rescue Exception => spawn_err
        puts("Failed spawning AWS node: #{spawn_err}")
      end
    end
    created_instances = {}
    until queue.empty?
      created_instances.merge!(queue.pop)
    end
    created_instances
  end

  def self.install_instance(hostname, options)
    Puppet.debug("Calling puppet node install with #{options.inspect}")
    Puppet::Face[:node, :current].install(hostname, options)
  end

  def self.create_instance(options, create_type = :node_aws)
    Puppet.debug("Calling puppet #{create_type} create with #{options.inspect}")
    Puppet::Face[create_type, :current].create(options)
  end

  # retrieve the queue instance
  def self.queue
    @queue ||= Queue.new
  end

end
