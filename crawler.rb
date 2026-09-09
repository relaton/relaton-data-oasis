# frozen_string_literal: true

require 'fileutils'
require 'relaton/oasis/data_fetcher'
require_relative 'index_builder'

FileUtils.rm_rf('data')
# Narrower than 'index*', which also matches index_builder.rb -- the crawler
# would then delete the very source it requires. relaton-data-bipm hit that bug;
# spec/crawler_sources_spec.rb guards it here.
FileUtils.rm Dir.glob('index-v*.{yaml,zip}')

# Writes the index of the day: index-v2.yaml once the pubid migration lands in
# the relaton gem, index-v1.yaml before it. Nothing zips here -- relaton/support's
# shared crawler.yml zips every index*.yaml that changed and commits both files.
Relaton::Oasis::DataFetcher.fetch

# index-v1, the legacy string-keyed index: rebuilt here over the data/ tree,
# because every released relaton line still reads index-v1.zip from this branch.
# Cross-checked against the index the fetch just wrote, so a document lost to a
# filename collision fails the crawl instead of silently shortening the index.
# Same arrangement as relaton-data-iana and relaton-data-etsi.
OasisIndexBuilder.build_index_v1
