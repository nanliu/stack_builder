dir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.join(dir, 'lib')

require 'mocha'
gem 'rspec', '>=2.0.0'
RSpec.configure do |config|
  config.mock_with :mocha
end
