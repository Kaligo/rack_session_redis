# frozen_string_literal: true

require_relative 'lib/redi_sesh/version'

Gem::Specification.new do |spec|
  spec.name = 'redi_sesh'
  spec.version = RediSesh::VERSION
  spec.authors = ['Hieu Nguyen', 'Kenneth Teh']
  spec.email = ['hieu.nguyen@kaligo.com', 'kenneth.teh@kaligo.com']

  spec.summary = 'Modified version of Rack::Session::Redis to support Redis 4.6.0 and 5.0.0'
  spec.homepage = 'https://github.com/Kaligo/redi_sesh'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/Kaligo/redi_sesh'
  spec.metadata['changelog_uri'] = 'https://github.com/Kaligo/redi_sesh/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'connection_pool'
  spec.add_runtime_dependency 'rack-session', '>= 0.2.0'
  spec.add_runtime_dependency 'redis', '>= 4.0'

  spec.metadata['rubygems_mfa_required'] = 'true'
end
