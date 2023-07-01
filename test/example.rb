#!/usr/bin/env ruby

def setup
  vete_retry or begin
    vete_init
    100.times {|i| vete_todo(i + 1) }
  end
  @time = Time.now
end

def perform(task)
  sleep rand
  secs = Time.now - @time # @time defined in setup
  exit 1 if rand < 0.08 # 8% chance of failure
end

require_relative "../lib/vete"
