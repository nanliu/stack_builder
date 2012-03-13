require 'spec_helper'
require 'puppet/face/stack'

describe Puppet::Face[:stack, :current] do

  let :options do
    {:name   => 'dans_stack',
     :config => 'some_config'
    }
  end

  describe 'build action' do

    it 'should call Puppet::Stack.build with those options' do
      Puppet::Stack.expects(:build).with(options)
      subject.build(options)
    end

    it 'should fail when no stack name is specfied' do
      options.delete(:name)
      expect do
        subject.build(options)
      end.should raise_error(ArgumentError, /The following options are required: name/)
    end

    it 'should fail when no config is specified' do
      options.delete(:config)
      expect do
        subject.build(options)
      end.should raise_error(ArgumentError, /The following options are required: config/)
    end
  end
end
