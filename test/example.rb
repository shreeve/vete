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
  exit 1 if rand < 0.03
  secs = Time.now - @time # @time defined in setup
end

require_relative "../lib/vete"
