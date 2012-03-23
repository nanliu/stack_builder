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
# TODO figure out how to abstract the thread code into a method that takes a
# block
# TODO figure out how to make master and nodes more similar to consolidate
# code paths
class Puppet::Stack

  def self.configure_logging
    # TODO I do not want to be setting up logging here
    # I need to figure out the correct way to just let faces do this
    Puppet::Util::Log.level = :debug
    Puppet::Util::Log.newdestination(:console)
  end

  # implements the build action
  def self.build(options)
    configure_logging
    nodes           = get_nodes(options[:config])
    created_nodes   = create(options, nodes)
    installed_nodes = install(options, nodes, created_nodes)
    test_results    = test(options, nodes, created_nodes)
  end


  def self.create(options, nodes)
    stack_file = File.join(get_stack_path, options[:name])
    begin
      file = File.new(stack_file, File::CREAT|File::EXCL)
    rescue Errno::EEXIST => ex
      raise(Puppet::Error, "Cannot create stack :#{options[:name]}, stackfile #{stack_file} already exists. Stack names supplied via --name must be unique")
    ensure
      file.close
    end
    # create the master and nodes
    created_nodes = {'config' => File.expand_path(options[:config])}
    created_nodes['master'] = create_instances([nodes['master']])
    created_nodes['nodes']  = create_instances(nodes['nodes'])

    # install all nodes that need to be installed
    save(stack_file, created_nodes)
    created_nodes
  end

  def self.install(options, nodes, created_nodes)
    # figure out the hostname of the master to connect to
    # TODO refactor this ugly code
    master_key = nodes['master'].keys[0]
    nodes['master'][master_key] ||= {}
    puppetmaster_hostname = if created_nodes['master'][master_key]
      created_nodes['master'][master_key]['hostname'] || master_key
    else
      master_key
    end

    # install all of the nodes
    installed_master = install_instances(
                         [nodes['master']],
                         created_nodes['master'],
                         # master type determines the script
                         # that we will use to install the master
                         nodes['master'].values[0]['master_type'] || 'master'
                       )
    installed_instances = nodes['nodes'] == {} ? nil :  install_instances(
                                                          nodes['nodes'],
                                                          created_nodes['nodes'],
                                                          nodes['puppet_run_type'],
                                                          puppetmaster_hostname
                                                        )
  end

  def self.test(options, nodes, created_nodes)
    install_instances(nodes['nodes'], created_nodes['nodes'], 'test')
  end

  def self.destroy(options)
    destroyed_dir = File.join(get_stack_path, 'destroyed')
    FileUtils.mkdir(destroyed_dir) unless File.directory?(destroyed_dir)
    stack_file = File.join(get_stack_path, options[:name])
    raise(Puppet::Error, "Stackfile for stack to destroy #{stack_file} does not exists. Stack names supplied via --name must have corresponding stack file to be destroyed") unless File.exists?(stack_file)
    stack = YAML.load_file(stack_file)
    ['master', 'nodes'].each do |type|
      stack[type].each do |k, attrs|
        Puppet.notice("Destroying #{type} #{attrs['hostname']}")
        Puppet::Face[:node_aws, :current].terminate(attrs['hostname'], {:region => attrs['region']})
      end
    end
    # keep a history of the stacks that we have destroyed
    FileUtils.mv(stack_file, File.join(destroyed_dir, "#{options[:name]}-#{Time.now.to_i}"))
  end

  def self.list(options)
    Puppet.notice('listing active stacks')
    stacks = {}
    Dir[File.expand_path(File.join(get_stack_path, '*'))].each do |file|
      if File.file?(file)
        stacks[File.basename(file)] = YAML.load_file(file)
      end
    end
    stacks
  end

  def self.tmux(options)
    raise(Puppet::Error, "Error: tmux not available, please install tmux.") if `which tmux`.empty?

    file    = File.join(get_stack_path, options[:name])
    systems = YAML.load_file(file) if File.file?(file)
    systems ||= {}

    config = get_nodes(options[:config])

    master = config['master'] || {}
    require 'pp'

    ssh = ''

    master.each do |name, opt|
      begin
        hostname = systems['master'][name]['hostname']
      rescue
        hostname = name
      end
      keyfile = opt['install']['options']['keyfile']
      login   = opt['install']['options']['login']
      ssh     = "'ssh -A -i #{keyfile} #{login}@#{hostname}'"
    end

    Puppet.debug "tmux new-session -s #{options[:name]} -n master -d #{ssh}"
    `tmux new-session -s #{options[:name]} -n master -d #{ssh}`

    nodenum = 1
    # We assume the connection info is consistent throughout create, install, test.
    nodes   = config['nodes'].inject({}) { |res, elm| res= elm.merge(res) }

    nodes.keys.sort.each do |name|
      opt = nodes[name]
      begin
        hostname = systems['nodes'][name]['hostname']
      rescue
        hostname = name
      end
      keyfile = opt['install']['options']['keyfile']
      login   = opt['install']['options']['login']
      ssh     = "'ssh -A -i #{keyfile} #{login}@#{hostname}'"

      Puppet.debug "tmux new-window -t #{options[:name]}:#{nodenum} -n #{name} #{ssh}"
      `tmux new-window -t #{options[:name]}:#{nodenum} -n #{name} #{ssh} 2>&1`
      nodenum += 1
    end

    puts "Connecting to session: tmux attach-session -t #{options[:name]}"
    `tmux attach-session -t #{options[:name]}`
  end

  def self.save(name, stack)
    File.open(name, 'w') do |fh|
      fh.puts(stack.to_yaml)
    end
  end

  # parse the nodes that compose the stack
  def self.get_nodes(config_file)
    config = YAML.load_file(File.expand_path(config_file)) ||
      {'nodes' => [], 'master' => {}}
    nodes  = process_config(config)
  end
  # takes a config file and returns a hash of
  # nodes to build
  def self.process_config(config_hash)
    nodes = {}
    master = {}
    defaults = get_defaults(config_hash)
    if config_hash['master']
      master = config_hash['master']
      raise(Puppet::Error, 'only a single master is supported') if master.size > 1
      master.each do |name, attr|
        if attr
          ['create', 'install'].each do |type|
            if master[name].has_key?(type)
              master[name][type] ||= {}
              master[name][type]['options'] =
                (defaults[type]['options'] || {}).merge(
                  attr[type]['options'] || {}
                )
            end
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
        node.each do |name, attrs|
          {
            'create'  => 'create',
            'install' => 'install',
            'test'    => 'install'
          }.each do |type, default_type|
            if attrs.has_key?(type)
              nodes[index][name][type] ||= {}
              nodes[index][name][type]['options'] =
                (defaults[default_type]['options'] || {}).merge(
                  attrs[type]['options'] || {}
                )
            end
          end
        end
      end
    end
    {
      'nodes' => nodes,
      'master' => master,
      'puppet_run_type' => config_hash['puppet_run_type'] || 'apply'
    }
  end

  def self.get_defaults(config_hash)
    # TODO - the user should be able to supply their defaults
    defaults = {}
    if(config_hash['defaults'])
      Puppet.debug('Getting defaults')
      ['create', 'install'].each do |d|
        defaults[d]= config_hash['defaults'][d] || {}
      end
    else
      Puppet.debug("No defaults specified")
      defaults = {'create' => {}, 'install' => {}}
    end
    defaults
  end

  # run what ever tests need to be run
  def self.test_instances(nodes, dns_hash)
    install_instances(nodes, dns_hash, 'test')
  end

  # install all of the nodes in order
  def self.install_instances(nodes, dns_hash, mode, master = nil)
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
          if ['pe_master', 'master', 'agent', 'apply'].include?(mode)
            run_type = 'install'
          elsif mode == 'test'
            run_type = 'test'
          else
            raise(Puppet::Error, "Unexpected mode #{mode}")
          end
          if attrs and attrs[run_type]
            Puppet.info("#{run_type.capitalize}ing instance #{name}")
            # the hostname is either the node id or the hostname value
            # in the case where we cannot determine the hostname
            hostname = dns_hash[name] ? dns_hash[name]['hostname'] : name
            certname = case(mode)
              when 'master', 'pe_master' then hostname
              else name
            end
            script_name = script_file_name(hostname)
            # compile our script into a file to perform puppet run
            File.open(File.join(script_dir, "#{script_name}.erb"), 'w') do |fh|
              fh.write(compile_erb(mode, attrs[run_type].merge('certname' => certname, 'puppetmaster' => master)))
            end
            threads << Thread.new do
              result = install_instance(
                hostname,
                (attrs[run_type]['options'] || {}).merge(
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

  # method that actually calls cloud provisioner
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
