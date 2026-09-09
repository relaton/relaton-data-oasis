# frozen_string_literal: true

source "https://rubygems.org"

# relaton-oasis no longer exists as a gem of its own -- the OASIS flavor lives
# in the combined `relaton` gem (relaton/relaton, gemspec at repo root), which
# is where `crawler.rb`'s `require "relaton/oasis/data_fetcher"` resolves.
#
# Pin `main` explicitly rather than leaving `github:` bare, for the reason
# relaton-data-bipm documents: an unpinned `github:` freezes whatever branch was
# current into Gemfile.lock, and relaton's remote churns many transient feature
# branches, so a later `bundle update` can fail fetching a deleted branch.
#
# NOTE: `main` does not carry the OASIS index-v2 producer yet. While that is
# true, `Relaton::Oasis::INDEXFILE` is "index-v1", the gem writes that file
# itself, and `index_builder.rb` reads it back as its own reference index -- so
# a crawl still publishes a correct `index-v1`, and the committed
# `index-v2.yaml`/`.zip` are NOT refreshed by it and go stale.
#
# The producer is unmerged and unpushed; the branch ref
# `feat/oasis-pubid-index-v2-producer` carries no commit above `main`, so no
# `git:` pin can reach it. Merging it -- see
# HANDOFFS/relaton__relaton__commit-oasis-index-v2-producer.md -- is what turns
# index-v2 production back on here, with no change to this file.
#
# To regenerate index-v2 before then, override this line locally with a `path:`
# pin to a working copy that carries the producer, and never commit it: the
# location is machine-specific, so CI fails at `bundle install`.
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

# This repo has to pin pubid itself: bundler reads a git gem's gemspec, never
# its Gemfile, so relaton's own pubid pin does not reach this bundle and a
# released pubid would be resolved instead. The latest release,
# 2.0.0.pre.alpha.9, predates `Pubid::Oasis::Identifier#number` -- the key
# `Relaton::Index::Type` sorts and binary-searches index-v2 on -- so a released
# pubid leaves it unset and every published row keys on "", silently degrading
# the search to a full scan.
#
# `pubid/pubid`, not `metanorma/pubid`: the repo was renamed. GitHub still
# redirects the old path, but only until someone creates a new repo at the old
# name -- at which point the pin would silently resolve to a different
# repository instead of failing.
#
# `Gemfile.lock` is git-ignored, so CI resolves fresh on every crawl. Verify
# with `bundle list | grep pubid` before trusting a generated index.
#
# TODO: revert to the released pubid once a release later than
# 2.0.0.pre.alpha.9 ships the OASIS `number` attribute.
gem "pubid", git: "https://github.com/pubid/pubid.git", branch: "main"

group :test do
  gem "rspec", "~> 3.13"
end
