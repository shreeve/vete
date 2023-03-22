#!/usr/bin/env ruby

def setup
  100.times {|i| vete_todo(i + 1) }
  @time = Time.now
end

def perform(slot, task)
  sleep rand
  secs = Time.now - @time
  exit 4 if rand < 0.02
end

require_relative "../lib/vete"
