# relaton-data-oasis

Bibliographic data for the OASIS flavor, plus the crawler that produces it.
`README.adoc` is the user-facing description; this file records what a future
session has to know before changing anything here.

## Layout

| Path | What it is |
| --- | --- |
| `data/*.yaml` | 605 Relaton YAML documents, one per OASIS publication. The source of truth. |
| `crawler.rb` | Fetches, then rebuilds `index-v1`. Deletes `data/` on load. |
| `index_builder.rb` | Rebuilds `index-v1.yaml` from `data/`. |
| `index-v1.yaml` / `.zip` | The legacy index every released relaton v2 consumer reads. |
| `spec/` | rspec, run with `bundle exec rspec`. No Rakefile, no CI workflow for specs. |

## The two indexes

`index-v2` is pubid-keyed and the **gem** owns it: `Relaton::Oasis::DataFetcher`
writes it with `pubid_class: ::Pubid::Oasis::Identifier`, and each row's `:id`
serialises to a `_type: pubid:oasis:standard` hash. `index-v1` is a flat list of
`{ :id, :file }` rows whose `:id` is the printed identifier string, and **this
repository** owns it. That split is what IANA, ETSI, BIPM, W3C and ECMA use.

## Why `index-v1` is rebuilt from `data/`, not derived from `index-v2`

Each document's primary `docidentifier` content **is** the v1 row id. relaton
writes that same string on both sides of the migration — `add_or_update
id.content, file` before, `Pubid::Oasis::Identifier.parse(id.content)` after —
so reading it from `data/` reproduces the published index exactly. Verified:
605 rebuilt rows equal the 605 published rows, sorted by `:file`.

Three things follow, and they are the reason for this choice:

- The rebuild needs **no pubid**, and no `Pubid::Oasis` at all.
- It is correct against relaton `main` (which still writes `index-v1`) **and**
  against the producer branch (which writes `index-v2`). `REFERENCE_FILES`
  prefers `index-v2.yaml` and falls back to `index-v1.yaml` for exactly this.
- Only the `docidentifier` field is read — never the whole bibitem — so relaton
  data-model drift cannot break the build.

## Row order changes; nothing depends on it

The rebuild emits **sorted glob order**. The published `index-v1.yaml` carries
crawl order. The first crawl on this branch therefore rewrites all 605 lines
with no content change, and re-zips. That is one-time and expected.

It is safe because no consumer reads the order.
`Relaton::Oasis::Bibliography#find_index_entry` is
`index.search(code).min_by { |r| r[:id] }`, and `Type#search_candidates` takes
the full-scan branch for a String query against a v1 index — there is no binary
search on the v1 path to depend on sorting.

So the specs compare **sorted by `:file`** and never assert order.

## The shadowed-id cross-check

A `data/` walk sees one identifier per file. `Core::DataFetcher#output_file` can
map two distinct identifiers onto one path, and a fetcher that overwrites
instead of disambiguating leaves the first document gone — its id then has no
file of its own and vanishes from the rebuild without any error.

`build_index_v1` reads the index the fetch just wrote, subtracts the ids the
`data/` walk found, and **raises naming the losers** rather than writing a short
index over a whole one. relaton-data-iana carries the same guard, and it is
currently red there for a real collision. Here it is green: 605 files, 605 ids,
0 shadowed.

Read the reference **before** writing, because it may be the very file being
written: a pre-migration relaton still writes `index-v1` itself.

## Never name a file `index*`

`crawler.rb` deletes its generated indexes before a crawl. The glob is
`index-v*.{yaml,zip}`, deliberately narrower than `index*`, which also matches
`index_builder.rb` — the crawler would delete the source it just required.
relaton-data-bipm hit that bug. `spec/crawler_sources_spec.rb` encodes it as a
rule, not a fix: no `Dir.glob` literal in `crawler.rb` may match a Ruby source,
and the globs must cover all four `index-v{1,2}.{yaml,zip}`.

## Nothing here zips

relaton/support's shared `crawler.yml` zips every `index*.yaml` that changed and
commits the yaml and the zip together; if a yaml did not change it restores the
zip from `HEAD`, so a byte-differing re-zip never lands. A zip written by
`crawler.rb` would fight that.

## Corpus facts

605 documents, 605 published rows, 605 distinct ids, 605 distinct files. Every
id is a String beginning with `OASIS `. Through pubid `main`, all 605 parse and
render back verbatim, 0 have an empty `root.number`, and they key 309 buckets
with the largest at 25.

Two published ids are malformed at the source — `OASIS CTAS-v3.0]-PS01` carries
a stray `]`, and `OASIS OpenC2-MQTT-v1.0] -CS01` carries a `]` and a
non-breaking space (U+00A0). They round-trip because
`Pubid::Oasis::Identifier` keeps the verbatim slug in `original` and the
renderer echoes it. They are the sharpest test of that contract.

## Running the specs

Always `bundle exec rspec`. Outside bundler the require order matters:
`relaton/index` pulls in `zip`, activating rubyzip 3.x, after which
lutaml-model's `rubyzip ~> 2.3` fails with `Gem::ConflictError`.

`spec/spec_helper.rb` requires `index_builder.rb` and never `crawler.rb`, which
deletes `data/` on load. `spec/crawler_sources_spec.rb` therefore reads the
crawler as source text.

## Dependency pins

`Gemfile.lock` is git-ignored, so every pin resolves fresh on each crawl.
`pubid` is pinned to `pubid/pubid@main`, which carries the OASIS flavor and
`#number`; the latest release does not.

**`relaton` carries a temporary local `path:` pin** to a working copy of the
OASIS index-v2 producer, which is unmerged and unpushed (the branch ref holds no
commit above `main`, so only a `path:` pin can reach it). That pin is what makes
a crawl write `index-v2.yaml` today.

It **must be reverted** to
`git: "https://github.com/relaton/relaton.git", branch: "main"` before this
branch merges: the path is machine-specific, so `bundle install` fails on any
runner while it stands. See
`HANDOFFS/relaton__relaton__commit-oasis-index-v2-producer.md`.

Reverting it is safe for the published `index-v1`. `index_builder.rb` reads
whichever index the resolved gem wrote — `REFERENCE_FILES` prefers
`index-v2.yaml` and falls back to `index-v1.yaml` — so the revert only stops
`index-v2` being produced, until the producer merges.
