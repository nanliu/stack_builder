require 'puppet/face'
require 'puppet'

Puppet::Face[:stack, :current].build(
  :config => 'config/oneiric_swift_multi',
  :name => Time.now.to_i
)
