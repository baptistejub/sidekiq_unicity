module SidekiqUnicity
  class TestLockManager
    def lock(...) = block_given? ? (yield true) : true
    def unlock(...) = true
  end
end
