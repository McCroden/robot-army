require File.dirname(__FILE__) + '/spec_helper'

class Example < RobotArmy::TaskMaster
  hosts %[www1.example.com www2.example.com]
end

class Localhost < RobotArmy::TaskMaster
  host nil
end

describe RobotArmy::TaskMaster do
  before do
    @master = Localhost.new
    @example = Example.new
  end
  
  it "allows setting host on the class" do
    Example.host 'example.com'
    Example.host.must == 'example.com'
    Example.hosts.must == %w[example.com]
  end
  
  it "allows setting multiple hosts on the class" do
    Example.hosts %w[example.com test.com]
    Example.host.must == 'example.com'
    Example.hosts.must == %w[example.com test.com]
  end
  
  it "runs a remote block on each host" do
    @example.should_receive(:remote_eval).exactly(2).times
    @example.remote { 3+4 }
  end
  
  it "returns an array of remote results when given multiple hosts" do
    @example.stub!(:remote_eval).and_return(7)
    @example.remote { 3+4 }.must == [7, 7]
  end
  
  it "can execute a Ruby block and return the result" do
    @master.remote { 3+4 }.must == 7
  end
  
  it "executes its block in a different process" do
    @master.remote { Process.pid }.must_not == Process.pid
  end
  
  it "preserves local variables" do
    a = 42
    @master.remote { a }.must == 42
  end
  
  it "warns about local variables that are not marshalable" do
    stdin = $stdin
    stderr_from { @master.remote { 42 } }.must =~ /WARNING: not including local variable 'stdin'/
  end
  
  it "does not declare non-marshalable locals" do
    stdin = $stdin
    silence_stderr { @master.remote { defined?(stdin) }.must be_nil }
  end
  
  it "re-raises exceptions thrown remotely" do
    proc { @master.remote { raise ArgumentError, "You fool!" } }.
      must raise_error(ArgumentError)
  end
  
  it "prints the child Ruby's stderr to stderr" do
    pending('we may not want to do this, even')
    stderr_from { @master.remote { $stderr.print "foo" } }.must == "foo"
  end
  
  it "runs multiple remote blocks for the same host in different processes" do
    @master.remote { $a = 1 }
    @master.remote { $a }.must be_nil
  end
  
  it "only loads one Officer process on the remote machine" do
    info = @master.connection(@master.host).info
    info[:pid].must_not == Process.pid
    info[:type].must == 'RobotArmy::Officer'
    @master.connection(@master.host).info.must == info
  end
  
  it "runs as a normal (non-super) user by default" do
    @master.remote{ Process.uid }.must_not == 0
  end
  
  it "allows running as super-user" do
    pending('figure out a way to run this only sometimes')
    @master.sudo{ Process.uid }.must == 0
  end
  
  it "loads dependencies" do
    @master.dependency "thor"
    @master.remote { Thor ; 45 }.must == 45 # loading should not bail here
  end
  
  it "delegates scp to the scp binary" do
    @master.should_receive(:system).with('scp file.tgz example.com:/tmp')
    @master.host = 'example.com'
    @master.scp 'file.tgz', '/tmp'
  end
  
  it "delegates to scp without a host when host is localhost" do
    @master.should_receive(:system).with('scp file.tgz /tmp')
    @master.scp 'file.tgz', '/tmp'
  end
end
