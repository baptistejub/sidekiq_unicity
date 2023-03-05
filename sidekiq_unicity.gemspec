require_relative "lib/sidekiq_unicity/version"

Gem::Specification.new do |spec|
  spec.name = "sidekiq_unicity"
  spec.version = SidekiqUnicity::VERSION
  spec.authors = ["Baptiste Jublot"]
  spec.email = ["baptiste.jublot@gmail.com"]

  spec.summary = "Unique jobs for Sidekiq"
  spec.description = "Ensure uniqueness of Sidekiq jobs"
  spec.homepage = "https://github.com/baptistejub/sidekiq_unicity"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "sidekiq", ">= 6"
  spec.add_dependency "redlock", ">= 2"

  spec.add_development_dependency 'bundler', '>= 2.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
