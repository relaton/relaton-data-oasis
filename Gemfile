# frozen_string_literal: true

source "https://rubygems.org"

# relaton-oasis no longer exists as a gem of its own -- the OASIS flavor lives
# in the combined `relaton` gem (relaton/relaton, gemspec at repo root), which
# is where `crawler.rb`'s `require "relaton/oasis/data_fetcher"` resolves.
#
# !!! TEMPORARY LOCAL PATH PIN -- MUST BE REVERTED BEFORE THIS BRANCH MERGES !!!
#
# The OASIS index-v2 producer is not merged and not pushed. It lives as
# uncommitted edits in a local relaton worktree, and the branch ref
# `feat/oasis-pubid-index-v2-producer` carries no commit above `main`, so no
# `git:` pin can reach that work -- only a `path:` pin, which reads the working
# tree. This is what makes a crawl here write `index-v2.yaml`.
#
# The path is ABSOLUTE deliberately: bundler resolves `path:` against the
# Gemfile's own directory, which is not the repo root when the Gemfile is read
# from a git worktree.
#
# CI CANNOT RESOLVE THIS. The location is machine-specific and the worktree is
# transient, so every crawl and every check on a runner fails at `bundle
# install` while this line stands. Restore the pin below before merging:
#
#   gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"
#
# `main` is pinned explicitly rather than left bare, for the reason
# relaton-data-bipm documents: an unpinned `github:` freezes whatever branch was
# current into Gemfile.lock, and relaton's remote churns many transient feature
# branches, so a later `bundle update` can fail fetching a deleted branch.
#
# Once the producer merges to relaton `main`, the git pin above is all that is
# needed -- see HANDOFFS/relaton__relaton__commit-oasis-index-v2-producer.md.
gem "relaton",
    path: "/Users/andrej/RubyProjects/ribose/relaton/relaton/.claude/worktrees/feat/oasis-pubid-index-v2-producer"

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
