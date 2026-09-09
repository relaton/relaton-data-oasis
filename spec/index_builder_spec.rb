# frozen_string_literal: true

# Behaviour of the index-v1 builder the crawler runs after the fetch. These
# exercise the real builder over throwaway corpora; no network, no fetch.
RSpec.describe OasisIndexBuilder do
  describe ".rows" do
    it "returns symbol-keyed rows in sorted glob order" do
      in_workdir("data/oasis-b.yaml" => doc("OASIS bravo"),
                 "data/oasis-a.yaml" => doc("OASIS alpha")) do
        expect(described_class.rows).to eq(
          [{ id: "OASIS alpha", file: "data/oasis-a.yaml" },
           { id: "OASIS bravo", file: "data/oasis-b.yaml" }],
        )
      end
    end

    # The fetcher indexes `doc.docidentifier.find(&:primary)`, so the builder
    # has to pick the same entry -- not simply the first one listed.
    it "takes the primary docidentifier, not the first" do
      record = { "docidentifier" => [
        { "content" => "OASIS secondary", "primary" => false },
        { "content" => "OASIS alpha", "primary" => true },
      ] }
      in_workdir("data/oasis-a.yaml" => record) do
        expect(described_class.rows.map { |r| r[:id] }).to eq ["OASIS alpha"]
      end
    end

    # Not every corpus marks a primary. Falling back to the first entry is what
    # `Relaton::Oasis::DataFetcher#save_doc` does, so the builder matches it.
    it "falls back to the first docidentifier when none is primary" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha", primary: false)) do
        expect(described_class.rows.map { |r| r[:id] }).to eq ["OASIS alpha"]
      end
    end

    it "warns and skips a data file with no docidentifier" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha"),
                 "data/broken.yaml" => { "docnumber" => "orphan" }) do
        rows = nil
        expect { rows = described_class.rows }
          .to output(%r{data/broken\.yaml}).to_stderr
        expect(rows).to eq([{ id: "OASIS alpha", file: "data/oasis-a.yaml" }])
      end
    end

    # One unreadable document must not abort the rebuild. The reference
    # cross-check in .build_index_v1 turns the resulting gap into a hard
    # failure that names the lost id, which is more use than a raw parse error.
    it "warns and skips an unparseable data file rather than aborting" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha"),
                 "data/bad.yaml" => "docidentifier: [unterminated\n") do
        rows = nil
        expect { rows = described_class.rows }
          .to output(%r{data/bad\.yaml: Psych}).to_stderr
        expect(rows).to eq([{ id: "OASIS alpha", file: "data/oasis-a.yaml" }])
      end
    end

    # Psych parses the whole document tree, so a date anywhere in the file --
    # not only in docidentifier -- decides whether the load succeeds.
    it "reads a document carrying an unquoted date" do
      record = "docidentifier:\n- content: OASIS alpha\n  primary: true\n" \
               "date:\n- type: issued\n  at: 2012-10-30\n"
      in_workdir("data/oasis-a.yaml" => record) do
        expect(described_class.rows)
          .to eq([{ id: "OASIS alpha", file: "data/oasis-a.yaml" }])
      end
    end
  end

  describe ".reference_ids" do
    # Once the producer lands, index-v2 is the only index the fetch writes.
    it "renders a v2 pubid row as the printed id" do
      in_workdir("index-v2.yaml" => [
        v2_row("amqp-core", "data/oasis-amqp-core.yaml"),
        v2_row("OSLC-CoreShapes-3.0-PS01-Pt8", "data/x.yaml",
               number: "OSLC-CoreShapes"),
      ]) do
        expect(described_class.reference_ids)
          .to eq(["OASIS amqp-core", "OASIS OSLC-CoreShapes-3.0-PS01-Pt8"])
      end
    end

    it "reads a v1 row's string id as-is" do
      in_workdir("index-v1.yaml" => [v1_row("OASIS amqp-core", "data/a.yaml")]) do
        expect(described_class.reference_ids).to eq(["OASIS amqp-core"])
      end
    end

    # The dispatch is on the row VALUE, not on the filename it came from, so a
    # transitional gem that writes String rows under the index-v2 name is read
    # correctly rather than raising. Nothing else pins that: both examples above
    # pair each shape with its usual filename.
    it "reads a string id under the index-v2 name" do
      in_workdir("index-v2.yaml" => [v1_row("OASIS amqp-core", "data/a.yaml")]) do
        expect(described_class.reference_ids).to eq(["OASIS amqp-core"])
      end
    end

    it "prefers index-v2.yaml over index-v1.yaml" do
      in_workdir("index-v2.yaml" => [v2_row("from-v2", "data/a.yaml")],
                 "index-v1.yaml" => [v1_row("OASIS from-v1", "data/a.yaml")]) do
        expect(described_class.reference_ids).to eq(["OASIS from-v2"])
      end
    end

    # A row written before the flavor carried `original` deserializes with it
    # nil and no error, so every id would render as a bare "OASIS ".
    it "raises on a v2 row with an empty or missing original" do
      in_workdir("index-v2.yaml" => [
        { id: { "_type" => "pubid:oasis:standard", "number" => "orphan" },
          file: "data/x.yaml" },
      ]) do
        expect { described_class.reference_ids }
          .to raise_error(described_class::Error, /Regenerate the index/)
      end
    end

    it "raises on a row id that is neither a string nor a hash" do
      in_workdir("index-v1.yaml" => [{ id: 42, file: "data/x.yaml" }]) do
        expect { described_class.reference_ids }
          .to raise_error(described_class::Error, /unexpected row id/)
      end
    end

    it "raises when no reference index exists" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha")) do
        expect { described_class.reference_ids }
          .to raise_error(described_class::Error, /index-v2\.yaml/)
      end
    end
  end

  describe ".build_index_v1" do
    it "writes the data/ rows for a corpus with no collision" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha"),
                 "data/oasis-b.yaml" => doc("OASIS bravo"),
                 "index-v2.yaml" => [v2_row("alpha", "data/oasis-a.yaml"),
                                     v2_row("bravo", "data/oasis-b.yaml")]) do
        expect(described_class.build_index_v1.size).to eq 2
        expect(YAML.safe_load_file("index-v1.yaml", permitted_classes: [Symbol]))
          .to eq([{ id: "OASIS alpha", file: "data/oasis-a.yaml" },
                  { id: "OASIS bravo", file: "data/oasis-b.yaml" }])
      end
    end

    # A data/ walk sees one docidentifier per file, so an id whose document was
    # overwritten by another is invisible to it. The reference index the fetch
    # just wrote is what makes the loss detectable.
    it "raises naming the shadowed id, and leaves index-v1.yaml untouched" do
      existing = [v1_row("OASIS alpha", "data/oasis-alpha.yaml"),
                  v1_row("OASIS alpha-one", "data/oasis-alpha.yaml")]
      in_workdir("data/oasis-alpha.yaml" => doc("OASIS alpha"),
                 "index-v1.yaml" => existing) do
        expect { described_class.build_index_v1 }
          .to raise_error(described_class::Error, /OASIS alpha-one/)
        expect(YAML.safe_load_file("index-v1.yaml", permitted_classes: [Symbol]))
          .to eq(existing)
      end
    end

    # The reference is read BEFORE the write, because it may BE the file being
    # written: a pre-migration relaton still writes index-v1 itself.
    it "rebuilds over an index-v1 that is its own reference" do
      in_workdir("data/oasis-a.yaml" => doc("OASIS alpha"),
                 "index-v1.yaml" => [v1_row("OASIS alpha", "data/old.yaml")]) do
        described_class.build_index_v1
        expect(YAML.safe_load_file("index-v1.yaml", permitted_classes: [Symbol]))
          .to eq([{ id: "OASIS alpha", file: "data/oasis-a.yaml" }])
      end
    end
  end

  # The acceptance test, against this repository's real committed corpus. It is
  # what proves the rebuild reproduces the file every released relaton v2
  # consumer reads -- nothing smaller covers all 605 rows.
  describe "the committed corpus" do
    let(:published) do
      YAML.safe_load(File.read(File.join(REPO_ROOT, "index-v1.yaml")),
                     permitted_classes: [Symbol])
    end

    let(:rebuilt) { Dir.chdir(REPO_ROOT) { described_class.rows } }

    it "reproduces the published index-v1 row for row" do
      # Sorted rather than `contain_exactly`, which compares 605 rows pairwise
      # and reports an unreadable diff on failure. Sorted by :file, not by
      # position: the rebuild emits sorted glob order where the published file
      # carries crawl order, and no consumer depends on the order --
      # `Bibliography#find_index_entry` is `search(code).min_by { |r| r[:id] }`.
      by_file = ->(rows) { rows.sort_by { |r| r[:file] } }
      expect(by_file.call(rebuilt)).to eq by_file.call(published)
    end

    it "keeps the published row count and shape" do
      expect(rebuilt.size).to eq 605
      expect(rebuilt.map { |r| r[:id] }.uniq.size).to eq 605
      expect(rebuilt.map { |r| r[:file] }.uniq.size).to eq 605
      expect(rebuilt.map { |r| r[:id].class }.uniq).to eq [String]
      expect(rebuilt.count { |r| r[:id].start_with?("OASIS ") }).to eq 605
    end

    # 605 documents, 605 published ids, nothing lost to a filename collision.
    # This is the tripwire: it goes red if a future crawl overwrites one
    # document with another instead of disambiguating the path.
    it "shadows no published id" do
      Dir.chdir(REPO_ROOT) do
        expect(described_class.shadowed_ids(described_class.rows,
                                            described_class.reference_ids))
          .to be_empty
      end
    end
  end
end
