# SidekiqUnicity

Job uniqueness for Sidekiq, using a lock mechanism powered by [Redlock](https://github.com/leandromoreira/redlock-rb).

The following strategies are supported:
| Lock strategy | Job is locked | Job is unlocked | Note
|-|-|-|-|
| `before_processing` | when pushed to the queue | when processing starts ||
| `during_processing` | when processing starts | when the job is processed (whatever the result) ||
| `before_and_during_processing` | when pushed to the queue | when the job is processed (whatever the result) | It's a dual lock combination of `before_processing` and `during_processing`. A `before_processing` lock is acquired when the job is pushed to the queue, then, when the job starts its processing, the `before_processing` lock is released and a `during_processing` lock is acquired. A new job can be pushed to the queue during processing.|
| `until_processed` | when pushed to the queue | when the job is processed (whatever the result) | Uses the same lock for the whole run, meaning no job can be pushed to the queue while the locked job isn't processed (where `before_and_during_processing` allows pushing jobs during the processing of the lock one) |

Jobs are unique across (enabled) queues, including retry and scheduled sets. This means that uniqueness applies even for a scheduled job or a job waiting to be retried (no similar job can be added).

Inspired by [SidekiqUniqueJobs](https://github.com/mhenrixon/sidekiq-unique-jobs) and [activejob-uniqueness](https://github.com/veeqo/activejob-uniqueness).

## Installation
Install the gem and add to the application's Gemfile by executing:

    $ bundle add sidekiq_unicity

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install sidekiq_unicity

## Usage

Add `SidekiqUnicity` to your Sidekiq initializer:
```ruby
SidekiqUnicity.configure
# OR
SidekiqUnicity.configure do |config|
  # optional config goes here
  # Exclude some queues from the uniqueness locks. The middlewares are completely skipped for these queues.
  config.excluded_queues = ['manual-ops']
  # Default lock ttl in seconds
  config.default_lock_ttl = 300
  # Default conflict strategy: :drop (default), :raise or :reschedule
  config.default_conflict_strategy = :drop
end
```

Set the options in your job:
```ruby
# Simple example
class MyJob
  include Sidekiq::Job

  sidekiq_unicity_options lock: :before_processing,
                          lock_key_proc: ->(args) { args.first }

  def perform(args)
    # [...]
  end
end
```

```ruby
# More complex example
class MyJob
  include Sidekiq::Job

  sidekiq_unicity_options lock: :before_and_during_processing,
                          lock_key_proc: ->(args) { args.first == 'book' ? args.second : 'global' },
                          lock_ttl: { before_processing: 30, during_processing: 60 },
                          conflict_strategy: {
                            before_processing: :drop,
                            during_processing: { name: :reschedule, options: { cool_down_duration: 10 } }
                          }

  def perform(type, stuff)
    # [...]
  end
end
```

### Options
#### lock (mandatory)
The lock strategy to use: `:before_processing`, `:during_processing` or `:before_and_during_processing`

#### lock_key_proc (mandatory)
Proc to generate a unique lock key for the job. Receives the job arguments.

#### lock_ttl
Duration of the lock, to prevent deadlocks. After `lock_ttl`, the lock automatically expires and new jobs can be queued/processed.
It's a safeguard to prevent deadlocks and thus blocking the job indefinitely, in case the job isn't properly unlocked (this should happen only with hard failures like Sidekiq or Redis crashes).
It's recommended to set it as short as possible.

"Before processing" lock TTL: how much time a job stays unique in the queue. Applies to :before_* strategies.
"During processing" lock TTL: how much time a job can run before another one can start being processed. Applies to :during_processing and :before_and_during_processing strategies.

Can be set globally using a Integer or customized by using a Hash.
```ruby
lock_ttl: 30
# or
lock_ttl: { before_processing: 30, during_processing: 60 }
```

Default to 300 seconds.

#### conflict_strategy
Strategy to apply when a job already exists.

Prebuilt strategies:
- `:drop`: job is discarded and a log is generated.
- `:raise`: an error is raised and the job follows the standard Sidekiq retry/death mechanism.
- `:reschedule`: the job is pushed to the scheduled job queue, to be performed `cool_down_duration` later.
Can be customized by using a Hash.

Also accepts any object responding to `#call` (like a Proc) that takes 2 arguments:
  1. job: the standard Sidekiq job Hash
  2. lock_key: String
Can be useful to customized behavior.

```ruby
# Always raise on conflict
conflict_strategy: :raise

# Discard the job if already on the queue and raise a error if another job is already being processed.
conflict_strategy: { before_processing: :drop, during_processing: :raise }

# :reschedule strategy can have a custom cool down duration to control when the job should be enqueue again.
# Default to 5 seconds.
conflict_strategy: { before_processing: :drop, during_processing: { name: :reschedule, options: { cool_down_duration: 30 } } }

# Using a custom strategy
conflict_strategy: ->(job, lock_key) { puts "Doing something" }
```

Default to `:drop`.

### Manual unlocking
Just in case, it's possible to manually unlock some jobs:
```ruby
# Unlock a specific job
SidekiqUnicity.manual_unlock(MyJobClass, 'unique_args')

# Unlock all the jobs for the given class
SidekiqUnicity.manual_unlock(MyJobClass)

# Unlock all the jobs
SidekiqUnicity.manual_unlock
```

Note: removing a job with Sidekiq API (UI or manually) doesn't clear the lock (at the time).

## Test mode
If you don't want to lock jobs in your test suite, activate the test mode:
```ruby
SidekiqUnicity.test_mode!
```

## Contributing

Bug reports and feature requests are welcome on GitHub at https://github.com/baptistejub/sidekiq_unicity.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
