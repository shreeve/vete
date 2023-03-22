# ============================================================================
# vete - Ruby CLI to spawn processes to get work done
#
# Author: Steve Shreeve (steve.shreeve@gmail.com)
#   Date: Mar 21, 2023
# ============================================================================
# TODO: 1) progress should update until all workers have *finished*
# ============================================================================

STDOUT.sync = true

# ==[ Command line ]==========================================================

require "fileutils"
require "optparse"
require "thread"

@pid = Process.pid

trap("INT"  ) { print clear + go; abort "\n" }
trap("WINCH") { print clear or draw if @pid == Process.pid }

OptionParser.new.instance_eval do
  @version = "0.2.0"
  @banner  = "usage: #{program_name} [options]"

  on "-b", "--bar <width>"            , "Progress bar width, in characters", Integer
  on "-c", "--char <character>"       , "Character to use for progress bar", String
  on "-r", "--reset"                  , "Remove directory used for job processing and quit"
  on "-h", "--help"                   , "Show help and command usage" do Kernel.abort to_s; end
  on "-v", "--version"                , "Show version number" do Kernel.abort "#{program_name} #{@version}"; end
  on "-w", "--workers <count>"        , "Set the number of workers (default is 1)", Integer

  self
end.parse!(into: opts={}) rescue abort($!.message)

# populate CLI options
@char = opts[:char   ] || "•"; @char = @char[0]
@nuke = opts[:reset  ]
@wide = opts[:bar    ] || 20
@work = opts[:workers] || 1

# define job directories
@vete = File.expand_path(".vete")
@todo = File.join(@vete, "todo")
@live = File.join(@vete, "live")
@done = File.join(@vete, "done")
@bomb = File.join(@vete, "bomb")

def move(path, dest)
  dest = File.join(dest, File.basename(path))
  FileUtils.mv(path, dest, force: true, secure: true)
end

def nuke
  FileUtils.rm_rf(@vete)
end

if @nuke
  nuke
  exit
end

def vete_init
  nuke
  list = [@todo, @live, @done, @bomb]
  list.each {|path| File.mkdir_p(path, force: true, secure: true) }
end

def vete_retry
  list = Dir.glob(File.join(@bomb, "*")).sort.each {|path| FileUtils.touch(path) }
  move(list, @todo)
end

def vete_todo(path)
  FileUtils.touch(path, force: true, secure: true)
end

# ==[ Drawing ]===============================================================

# https://www.cse.psu.edu/~kxc104/class/cmpen472/16f/hw/hw8/vt100ansi.htm

def clear      ; "\e[2J"                        ; end
def cursor(on) ; print on ? "\e[?25h": "\e[?25l"; end
def go(r=1,c=1); "\e[#{r};#{c}H"                ; end
def go!(...)   ; print go(...)                  ; end

def fg(rgb=nil); rgb ? "\e[38;2;#{hx(rgb)}m" : "\e[39m"; end
def bg(rgb=nil); rgb ? "\e[48;2;#{hx(rgb)}m" : "\e[49m"; end
def hx(str=nil); str =~ /\A#?(?:(\h\h)(\h\h)(\h\h)|(\h)(\h)(\h))\z/ or return
  r, g, b = $1 ? [$1, $2, $3] : [$4*2, $5*2, $6*2]
  [r.hex, g.hex, b.hex] * ";"
end

def draw(done=0, live=0, bomb=0, jobs=0, info=nil)

  # outer box
  unless info
    print [
      clear,
      go(2 + @work, @len + 3) + "└" + "─" * (@wide + 2) + "┘\n",
      go(1        , @len + 3) + "┌" + "─" * (@wide + 2) + "┐\n",
    ].join
    @work.times {|i| print " %*d │ %*s │\n" % [@len, i + 1, @wide, ""] }
    return
  end

  # worker bars
  dpct = done.to_f / jobs
  lpct = live.to_f / jobs
  most = info.values.max
  info.each do |slot, this|
    tpct = this.to_f / most
    cols = dpct * tpct * @wide
    print go(slot + 1, @len + 5) + bg("5383ec") + @char * cols
  end

  # summary bar
  gcol = dpct * @wide
  ycol = lpct * @wide
  print [
    go(@work + 3, @len + 5),
    fg("fff"),
    bg("58a65c") + @char * (       gcol       )     , #  green (done)
    bg("f1bf42") + @char * (              ycol)     , # yellow (live) <= Add live
    bg("d85140") + " "  * (@wide - gcol - ycol).ceil, #    red (left)
    go(@work + 3, @len + 5 + @wide + 3) + " %.1f%% done " % [dpct * 100],
    bomb == 0 ? nil : (bg + " " + bg("f1bf42") + " #{bomb} bombed "),
  ].join

  # clear colors
  print fg + bg
end

# ==[ Simulate job creation, add helpers so vete makes this easy ]============

FileUtils.rm_rf   @vete
FileUtils.mkdir_p @todo
FileUtils.mkdir_p @live
FileUtils.mkdir_p @done
FileUtils.mkdir_p @bomb

100.times {|i| FileUtils.touch(File.join(@todo, (i + 1).to_s)) }

# ==[ Configure workers ]=====================================================

@len = @work.to_s.size
@mtx = Mutex.new
@que = Thread::Queue.new; @work.times {|slot| @que << (slot + 1) }

begin
  list = Dir[File.join(@todo, "*")]
  jobs = list.size
  info = Hash.new(0)

  setup if defined?(setup)

  cursor(false)
  time = Time.now
  draw
  done = 0
  live = 0
  bomb = 0
  Thread.new do
    list.each do |path|
      slot = @que.pop
      @mtx.synchronize {
        live += 1
      }
      show = "Working on task " + File.basename(path)
      print go(slot + 1, @len + 5 + @wide + 3) + show
      if chld = fork # parent
        Thread.new do
          okay = Process.waitpid2(chld)[1] == 0
          move(path, okay ? @done : @bomb)
          @que.push(slot)
          @mtx.synchronize {
            done += 1
            live -= 1
            bomb += 1 unless okay
            info[slot] += 1
          }
        end
        draw(done, live, bomb, jobs, info.dup)
      else
        perform(slot, path)
        exit
      end
    end
  end.join
  secs = Time.now.to_f - time.to_f

  # summary
  print [
    go(@work + 5, 1),
    "%.2f secs" % secs,
    " for #{jobs} jobs",
    " by #{@work} workers",
    " @ %.2f jobs/sec" % [jobs / secs]
  ].join + "\n\n"

ensure
  cursor(true)
end
