#!/usr/bin/env ruby

def setup
  vete_retry or begin # retry prior failed tasks, or
    vete_init # initialize the main task directory structure
    100.times {|i| vete_todo(i + 1) } # create 100 new tasks
  end
  @time = Time.now # instance variables are visible to each task
end

def perform(task)
  sleep rand # simulate some work performed
  secs = Time.now - @time # do something with @time (defined in setup)
  exit 1 if rand < 0.03 # simulate a 3% chance of failure
end

require "vete"
