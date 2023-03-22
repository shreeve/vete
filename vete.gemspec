# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = "vete"
  s.version     = `grep -m 1 '^\s*@version' lib/vete.rb | cut -f 2 -d '"'`
  s.author      = "Steve Shreeve"
  s.email       = "steve.shreeve@gmail.com"
  s.summary     =
  s.description = "Ruby CLI to spawn processes to get work done"
  s.homepage    = "https://github.com/shreeve/vete"
  s.license     = "MIT"
  s.files       = `git ls-files`.split("\n") - %w[.gitignore]
  s.executables = `cd bin && git ls-files .`.split("\n")
end
