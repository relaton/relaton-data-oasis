# frozen_string_literal: true

require "date"
require "yaml"

# Builds the legacy `index-v1.yaml` this repository publishes.
#
# The `relaton` gem's `Relaton::Oasis::DataFetcher` writes only the index of the
# day -- `index-v2` once the pubid migration lands, `index-v1` before it. Every
# released `relaton` line still reads `index-v1.zip` from this repo's `v2`
# branch, so the crawler keeps producing it here. relaton-data-iana,
# relaton-data-etsi and relaton-data-bipm carry the same arrangement.
#
# The rows are rebuilt from the `data/` tree rather than derived from
# `index-v2.yaml`: each document's primary `docidentifier` content IS the v1 row
# id, because that is the string relaton writes on both sides of the migration
# (`index.add_or_update id.content, file` before it, and
# `Pubid::Oasis::Identifier.parse(id.content)` after). Reading it here keeps the
# rebuild independent of which index the gem happens to write, and free of pubid
# entirely. Only `docidentifier` is read -- no bibitem deserialization -- so
# data-model drift cannot break the build.
#
# A `data/` walk sees one docidentifier per file, though, and two docidentifiers
# can collide on one filename (see .build_index_v1). The index the fetch just
# wrote is therefore used as the authoritative id set to detect that loss.
#
# Nothing here zips. relaton/support's shared `crawler.yml` zips every
# `index*.yaml` that changed and commits the yaml and the zip together.
module OasisIndexBuilder
  Error = Class.new(StandardError)

  DATA_GLOB = "data/**/*.yaml"
  INDEX_V1 = "index-v1.yaml"
  # index-v2 first: once the producer lands it is the only index the fetch
  # writes. index-v1 is the fallback for the pre-migration gem, which still
  # writes it -- and which is therefore its own reference.
  REFERENCE_FILES = %w[index-v2.yaml index-v1.yaml].freeze

  # The publisher token every OASIS printed id carries. A v2 row stores the
  # slug after it, in `original`; v1 stores the whole printed string.
  PUBLISHER = "OASIS"

  module_function

  # The index-v1 rows: `{ id: <printed docidentifier>, file: <path> }` in sorted
  # glob order. A document with no usable docidentifier is warned about and
  # skipped; the reference cross-check in .build_index_v1 turns that into a hard
  # failure.
  #
  # @param [String] glob the data/ glob to walk
  #
  # @return [Array<Hash>] the rows
  def rows(glob: DATA_GLOB)
    Dir[glob].sort.filter_map do |file|
      id = docidentifier(file)
      # `warn` returns nil, which filter_map drops.
      next warn("index-v1: skipping #{file}: no docidentifier") if id.to_s.empty?

      { id: id, file: file }
    rescue StandardError => e
      # One unreadable document must not abort the rebuild, as in
      # relaton-data-iana's index_builder.rb. The reference cross-check in
      # .build_index_v1 turns the resulting gap into a hard failure that names
      # the lost id, which is more use than a raw parse error here.
      warn "index-v1: skipping #{file}: #{e.class}: #{e.message}"
    end
  end

  # The authoritative `{ id:, file: }` rows, from the first reference index that
  # exists.
  #
  # @param [Array<String>] files the candidate reference indexes, in preference
  #   order
  #
  # @return [Array<Hash>] the rows, ids rendered to their printed form
  def reference_rows(files: REFERENCE_FILES)
    file = files.find { |f| File.exist? f }
    unless file
      raise Error, "no reference index found (looked for #{files.join ', '}); " \
                   "did Relaton::Oasis::DataFetcher.fetch run?"
    end

    load_index(file).map do |row|
      { id: reference_id(row[:id], file), file: row[:file] }
    end
  end

  # Just the ids of .reference_rows.
  #
  # @return [Array<String>] the printed ids
  def reference_ids(files: REFERENCE_FILES)
    reference_rows(files: files).map { |row| row[:id] }
  end

  # Reference ids that no data file carries -- ids lost to a filename collision.
  #
  # @param [Array<Hash>] rows .rows output, `{ id:, file: }` hashes
  # @param [Array<String>] ids .reference_ids output, plain id strings
  #
  # @return [Array<String>] the shadowed ids
  def shadowed_ids(rows, ids)
    ids - rows.map { |row| row[:id] }
  end

  # Rebuild INDEX_V1 from the data/ tree.
  #
  # Raises when a reference id has no data file of its own.
  # `Relaton::Core::DataFetcher#output_file` collapses distinct docidentifiers
  # onto one path, and a fetcher that overwrites instead of disambiguating
  # leaves the first document gone and its id unbuildable from data/. That is a
  # relaton bug, not something to route around here -- name the lost ids and
  # stop, rather than publish a short index over a whole one.
  #
  # @return [Array<Hash>] the rows written
  def build_index_v1(file: INDEX_V1, glob: DATA_GLOB,
                     reference_files: REFERENCE_FILES)
    # Read the reference before writing: it may BE `file` (pre-migration gem).
    reference = reference_rows(files: reference_files)
    data_rows = rows(glob: glob)
    check_shadowed! data_rows, reference

    # Plain File.write, not Relaton::Index. For symbol-keyed String-id rows this
    # is byte-identical to what `Relaton::Index::Type#save` emits, and it keeps
    # the builder off the process-wide Type pool the fetcher fills.
    File.write file, data_rows.to_yaml
    puts "index-v1: wrote #{data_rows.size} entries to #{file}"
    data_rows
  end

  # -- internals --------------------------------------------------------------

  # The printed id of one document: the primary `docidentifier` content, falling
  # back to the first entry, which is what
  # `Relaton::Oasis::DataFetcher#save_doc` indexes.
  #
  # Only that one field is read, never the whole bibliographic item, so data
  # model drift in the relaton gem cannot break the rebuild. Psych still parses
  # the entire document tree, though, so Date/Time are permitted: one unquoted
  # date anywhere in one record would otherwise raise Psych::DisallowedClass.
  def docidentifier(file)
    doc = YAML.safe_load_file(file, permitted_classes: [Date, Time])
    return nil unless doc.is_a? Hash

    ids = doc["docidentifier"]
    return nil unless ids.is_a? Array

    id = ids.find { |i| i.is_a?(Hash) && i["primary"] } || ids.first
    id["content"] if id.is_a? Hash
  end

  def load_index(file)
    YAML.safe_load(File.read(file), permitted_classes: [Symbol])
  end

  # A v1 row's id is the printed string itself; a v2 row's is the pubid hash,
  # whose printed form is the publisher token joined to `original`. Reading
  # `original` rather than parsing the hash back into a pubid keeps this file
  # free of pubid altogether.
  def reference_id(id, file)
    return id if id.is_a? String
    raise Error, "#{file}: unexpected row id #{id.inspect}" unless id.is_a? Hash

    original = id["original"].to_s
    if original.empty?
      raise Error, "#{file}: row #{id.inspect} has no original -- a row " \
                   "written before the flavor carried it deserializes " \
                   "silently as nil. Regenerate the index."
    end

    "#{PUBLISHER} #{original}"
  end

  def check_shadowed!(data_rows, reference)
    by_id = reference.to_h { |row| [row[:id], row[:file]] }
    shadowed = shadowed_ids(data_rows, by_id.keys)
    return if shadowed.empty?

    detail = shadowed.map { |id| "  #{id} -> #{by_id[id]}" }.join("\n")
    raise Error, "index-v1: #{shadowed.size} id(s) have no data file of their " \
                 "own -- distinct docidentifiers collided on one filename and " \
                 "the fetcher overwrote instead of disambiguating:\n#{detail}\n" \
                 "Fix the collision in the relaton gem, then re-run the crawl."
  end
end
