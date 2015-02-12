# -*- encoding: utf-8 -*-
# stub: ancestry 2.1.4 ruby lib

Gem::Specification.new do |s|
  s.name = "ancestry"
  s.version = "2.1.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Stefan Kroes [enhancements for multi-parent nodes by tjchambers]"]
  s.date = "2015-01-22"
  s.description = "Organise ActiveRecord model into a tree structure"
  s.email = "tchambers@schellingpoint.com"
  s.files = ["MIT-LICENSE", "README.rdoc", "ancestry.gemspec", "init.rb", "install.rb", "lib/ancestry.rb", "lib/ancestry/class_methods.rb", "lib/ancestry/exceptions.rb", "lib/ancestry/has_ancestry.rb", "lib/ancestry/instance_methods.rb"]
  s.homepage = "http://github.com/tjchambers/ancestry"
  s.rubygems_version = "2.4.3"
  s.summary = "Ancestry allows the records of a ActiveRecord model to be organised in a tree structure, using a single, intuitively formatted database column. It exposes all the standard tree structure relations (ancestors, parent, root, children, siblings, descendants) and all of them can be fetched in a single sql query. Additional features are named_scopes, integrity checking, integrity restoration, arrangement of (sub)tree into hashes and different strategies for dealing with orphaned records."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<activerecord>, [">= 4.0.0"])
    else
      s.add_dependency(%q<activerecord>, [">= 4.0.0"])
    end
  else
    s.add_dependency(%q<activerecord>, [">= 4.0.0"])
  end
end
