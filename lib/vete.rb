# ============================================================================
# vete - Ruby CLI to spawn processes to get work done
#
# Author: Steve Shreeve (steve.shreeve@gmail.com)
#   Date: July 1, 2023
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
  @version = "1.0.1"
  @banner  = "usage: #{program_name} [options]"

  on "-b", "--bar <width>"            , "Progress bar width, in characters", Integer
  on "-c", "--char <character>"       , "Character to use for progress bar", String
  on "-d", "--delay <mode>"           , "Delay mode (rand, task, numeric)"
  on "-h", "--help"                   , "Show help and command usage" do Kernel.abort to_s; end
  on "-r", "--reset"                  , "Remove directory used for job processing and quit"
  on "-v", "--version"                , "Show version number" do Kernel.abort "#{program_name} #{@version}"; end
  on "-w", "--workers <count>"        , "Set the number of workers (default is 1)", Integer

  self
end.parse!(into: @opts = opts = {}) rescue abort($!.message)

# populate CLI options
@char = opts[:char   ] || "•"; @char = @char[0]
@wait = opts[:delay  ]
@nuke = opts[:reset  ]
@wide = opts[:bar    ] || 20
@work = opts[:workers] || 1

# handle wait mode
case @wait
when "rand", "task", nil
when /\A(?:0|[1-9]\d*|(?:0?\.|[1-9]\d*\.)\d*)\z/
  @wait = @wait.to_f
  @wait > 0 or abort "invalid delay time (#{@wait.to_f} secs)"
else
  abort "invalid delay mode '#{@wait}'"
end

# define job directories
@vete = File.expand_path(".vete")
@todo = File.join(@vete, "todo")
@done = File.join(@vete, "done")
@died = File.join(@vete, "died")

def move(path, dest)
  dest = File.join(dest, File.basename(path)) unless path.is_a?(Array)
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
  list = [@todo, @done, @died]
  list.each {|path| FileUtils.mkdir_p(path) }
end

def vete_retry
  list = Dir.glob(File.join(@died, "*")).sort.each {|path| FileUtils.touch(path) }
  list.empty? ? false : !!move(list, @todo)
end

def vete_todo(path, data=nil)
  path = File.join(@todo, path.to_s)
  data ? File.write(path, data) : FileUtils.touch(path)
end

# ==[ Drawing ]===============================================================

# https://www.cse.psu.edu/~kxc104/class/cmpen472/16f/hw/hw8/vt100ansi.htm

def clear(line=nil); line ? "\e[K" : "\e[2J"        ; end
def cursor(on)     ; print on ? "\e[?25h": "\e[?25l"; end
def go(r=1,c=1)    ; "\e[#{r};#{c}H"                ; end
def go!(...)       ; print go(...)                  ; end

@hex={}

def hex(str=nil)
  @hex[str] ||= begin
    str =~ /\A#?(?:(\h\h)(\h\h)(\h\h)|(\h)(\h)(\h))\z/ or return
    r, g, b = $1 ? [$1, $2, $3] : [$4*2, $5*2, $6*2]
    [r.hex, g.hex, b.hex] * ";"
  end
end

def fg(rgb=nil); rgb ? "\e[38;2;#{hex(rgb)}m" : "\e[39m"; end
def bg(rgb=nil); rgb ? "\e[48;2;#{hex(rgb)}m" : "\e[49m"; end

def draw(live=0, done=0, died=0, jobs=0, info=nil)

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
  ppct = (done + died).to_f / jobs
  most = info.values.max
  info.each do |slot, this|
    tpct = this.to_f / most
    cols = ppct * tpct * @wide
    print go(slot + 1, @len + 5) + bg("5383ec") + @char * cols # fg("fff")
  end

  # summary bar
  dpct = done.to_f / jobs
  lpct = live.to_f / jobs
  gcol = dpct * @wide
  ycol = lpct * @wide
  print [
    go(@work + 3, @len + 5),
    fg("fff"),
    bg("58a65c") + @char * (       gcol       ),      #  green (done)
    bg("f1bf42") + @char * (              ycol),      # yellow (live)
    bg("d85140") + " "  * (@wide - gcol - ycol).ceil, #    red (rest)
    go(@work + 3, @len + 5 + @wide + 3),
    bg("5383ec") + " %.1f%% " % [ppct * 100],         #   blue (done + died)
    done > 0 ? (bg + " " + bg("58a65c") + " #{done}/#{jobs} done ") : nil,
    died > 0 ? (bg + " " + bg("d85140") +         " #{died} died ") : nil,
  ].join

  # clear colors
  print fg + bg
end

# ==[ Configure workers ]=====================================================

@len = @work.to_s.size
@mtx = Mutex.new
@que = Thread::Queue.new; @work.times {|slot| @que << (slot + 1) }

defined?(setup  ) and setup
defined?(perform) and list = Dir[File.join(@todo, "*")] and !list.empty? and begin
  live = 0
  done = 0
  died = 0
  jobs = list.size
  info = Hash.new(0)

  cursor(false)
  draw

  time = Time.now
  Thread.new do
    list.each_with_index do |path, task|
      slot = @que.pop
      @mtx.synchronize {
        live += 1
      }
      show = "Working on task " + File.basename(path)
      print go(slot + 1, @len + 5 + @wide + 3) + show + clear(true)
      if chld = fork # parent
        Thread.new do
          okay = Process.waitpid2(chld)[1] == 0
          move(path, okay ? @done : @died)
          @que.push(slot)
          @mtx.synchronize {
            live -= 1
            okay ? (done += 1) : (died += 1)
            info[slot] += 1
          }
        end
        draw(live, done, died, jobs, info.dup)
      else
        case @wait
        when "rand"  then sleep rand(@work)
        when "task"  then sleep task
        when Numeric then sleep task * @wait
        end if task < @work
        perform(path)
        exit
      end
    end
    while @que.size != @work
      sleep 0.3
      draw(live, done, died, jobs, info.dup)
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
