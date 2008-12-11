#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/file_locking'

describe Puppet::Util::FileLocking do
    it "should be able to keep file corruption from happening when there are multiple writers" do
        file = Tempfile.new("puppetspec")
        file.close!()
        file = file.path
        File.open(file, "w") { |f| f.puts "starting" }

        value = {:a => :b}
        threads = []
        sync = Sync.new
        9.times { |a|
            threads << Thread.new {
                9.times { |b|
                    sync.synchronize(Sync::SH) {
                        Puppet::Util::FileLocking.readlock(file) { |f|
                            f.read
                        }
                    }
                    sleep 0.01
                    sync.synchronize(Sync::EX) {
                        Puppet::Util::FileLocking.writelock(file) { |f|
                            f.puts "%s %s" % [a, b]
                        }
                    }
                }
            }
        }
        threads.each { |th| th.join }
    end
end
