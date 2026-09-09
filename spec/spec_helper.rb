# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "yaml"

require_relative "../index_builder"

# Absolute path to the repo root, so a spec can reach the real committed corpus
# (`data/`, `index-v1.yaml`) from inside an `in_workdir` chdir.
REPO_ROOT = File.expand_path("..", __dir__)

module WorkdirHelper
  # Run the block in a throwaway directory seeded with +files+, so the builder's
  # CWD-relative `data/**/*.yaml` glob and its `index-v1.yaml` write never touch
  # the repo. A Hash value is dumped as YAML; a String is written verbatim.
  def in_workdir(files = {})
    Dir.mktmpdir do |dir|
      files.each do |path, content|
        full = File.join(dir, path)
        FileUtils.mkdir_p File.dirname(full)
        File.write full, content.is_a?(String) ? content : content.to_yaml
      end
      Dir.chdir(dir) { yield dir }
    end
  end

  # A minimal data/ document. The builder reads only `docidentifier`, so
  # nothing else is needed to exercise it.
  def doc(content, primary: true)
    { "docnumber" => content.sub(/\AOASIS /, ""),
      "docidentifier" => [{ "content" => content, "type" => "OASIS",
                            "primary" => primary }] }
  end

  # One `index-v2.yaml` row, in the shape `Relaton::Index` writes for a
  # `Pubid::Oasis::Identifier`: the `:id` is a hash with STRING keys, and
  # `original` is the slug after the "OASIS " publisher token.
  def v2_row(original, file, number: original)
    { id: { "_type" => "pubid:oasis:standard", "original" => original,
            "number" => number }.compact,
      file: file }
  end

  # One legacy `index-v1.yaml` row: the printed id, verbatim.
  def v1_row(id, file)
    { id: id, file: file }
  end
end

RSpec.configure do |config|
  config.include WorkdirHelper
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
end
