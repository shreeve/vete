#!/usr/bin/env ruby

def setup
  @time = Time.now
end

def perform(slot, task)
  sleep rand
  secs = Time.now - @time
  exit 4 if rand < 0.02
end

require_relative "../lib/vete"
