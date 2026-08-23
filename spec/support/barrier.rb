# Holds each thread until every one of them has arrived, so they contend at the
# same moment rather than filing past one after another. Without it a
# concurrency example usually just runs its threads in sequence and proves
# nothing.
class Barrier
  def initialize(count)
    @count = count
    @arrived = 0
    @mutex = Mutex.new
    @condition = ConditionVariable.new
  end

  def wait
    @mutex.synchronize do
      @arrived += 1

      if @arrived >= @count
        @condition.broadcast
      else
        @condition.wait(@mutex)
      end
    end
  end
end
