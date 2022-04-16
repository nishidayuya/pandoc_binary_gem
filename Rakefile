# frozen_string_literal: true

require "bundler/gem_tasks"

gitignore_path = (Pathname(__dir__).expand_path / ".gitignore")
libexec_executable_paths = gitignore_path.
                             each_line(chomp: true).
                             lazy.
                             grep(%r{\A/libexec/}).
                             map { |path| Pathname(path.sub(%r{\A/}, "")) }
CLOBBER.include(*libexec_executable_paths)

task default: %i[]
