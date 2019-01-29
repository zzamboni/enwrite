# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: enwrite 0.2.5 ruby lib

Gem::Specification.new do |s|
  s.name = "enwrite".freeze
  s.version = "0.2.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Diego Zamboni".freeze]
  s.date = "2018-08-28"
  s.description = "Enwrite allows you to generate a website from content stored in Evernote.".freeze
  s.email = "diego@zzamboni.org".freeze
  s.executables = ["enwrite".freeze]
  s.extra_rdoc_files = [
    "LICENSE",
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "bin/enwrite",
    "enwrite.gemspec",
    "lib/enml-utils.rb",
    "lib/enwrite.rb",
    "lib/evernote-utils.rb",
    "lib/filters.rb",
    "lib/output.rb",
    "lib/output/hugo.rb",
    "lib/util.rb",
    "test/helper.rb",
    "test/test_enwrite.rb"
  ]
  s.homepage = "http://github.com/zzamboni/enwrite".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "2.7.6".freeze
  s.summary = "Enwrite: Power a web site using Evernote".freeze

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<colorize>.freeze, ["~> 0.7"])
      s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
      s.add_runtime_dependency(%q<evernote-thrift>.freeze, ["~> 1.25"])
      s.add_runtime_dependency(%q<evernote_oauth>.freeze, ["~> 0.2"])
      s.add_runtime_dependency(%q<htmlentities>.freeze, ["~> 4.3"])
      s.add_development_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>.freeze, ["~> 1.0"])
      s.add_development_dependency(%q<jeweler>.freeze, ["~> 2.0"])
    else
      s.add_dependency(%q<colorize>.freeze, ["~> 0.7"])
      s.add_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
      s.add_dependency(%q<evernote-thrift>.freeze, ["~> 1.25"])
      s.add_dependency(%q<evernote_oauth>.freeze, ["~> 0.2"])
      s.add_dependency(%q<htmlentities>.freeze, ["~> 4.3"])
      s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
      s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
      s.add_dependency(%q<jeweler>.freeze, ["~> 2.0"])
    end
  else
    s.add_dependency(%q<colorize>.freeze, ["~> 0.7"])
    s.add_dependency(%q<deep_merge>.freeze, ["~> 1.0"])
    s.add_dependency(%q<evernote-thrift>.freeze, ["~> 1.25"])
    s.add_dependency(%q<evernote_oauth>.freeze, ["~> 0.2"])
    s.add_dependency(%q<htmlentities>.freeze, ["~> 4.3"])
    s.add_dependency(%q<rdoc>.freeze, ["~> 3.12"])
    s.add_dependency(%q<bundler>.freeze, ["~> 1.0"])
    s.add_dependency(%q<jeweler>.freeze, ["~> 2.0"])
  end
end

