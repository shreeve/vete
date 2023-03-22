#!/usr/bin/env ruby

def setup
  vete_init
  100.times {|i| vete_todo(i + 1) }
  @time = Time.now
end

def perform(task)
  sleep rand
  secs = Time.now - @time
  exit 4 if rand < 0.3
end

require_relative "../lib/vete"
