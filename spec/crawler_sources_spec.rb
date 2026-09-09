# frozen_string_literal: true

# `crawler.rb` deletes `data/` on load, so it cannot be required. Read it as
# source text instead, the way relaton-data-iana and relaton-data-bipm guard
# their own crawlers.
RSpec.describe "crawler.rb" do
  let(:source) { File.read(File.join(REPO_ROOT, "crawler.rb")) }

  # A bare `index*` glob also matches `index_builder.rb` beside it, and the
  # crawler would delete the very source it requires. relaton-data-bipm hit this
  # exact bug. Guard the names a future session is most likely to add too, not
  # only the one here today.
  it "removes the generated index files, not a Ruby source beside them" do
    globs = source.scan(/Dir\.glob\(["']([^"']+)["']\)/).flatten
    expect(globs).not_to be_empty
    %w[index_builder.rb derive_index_v1.rb crawler.rb].each do |ruby|
      globs.each do |glob|
        expect(File.fnmatch(glob, ruby, File::FNM_EXTGLOB))
          .to be(false), "glob #{glob.inspect} matches #{ruby}"
      end
    end
    %w[index-v1.yaml index-v1.zip index-v2.yaml index-v2.zip].each do |file|
      expect(globs.any? { |g| File.fnmatch(g, file, File::FNM_EXTGLOB) })
        .to be(true), "no glob matches #{file}"
    end
  end

  # Order is the contract: `build_index_v1` cross-checks against the index the
  # fetch just wrote. Run first, it would find no reference index and raise.
  it "builds index-v1 after the fetch" do
    fetch = source.index("Relaton::Oasis::DataFetcher.fetch")
    build = source.index("OasisIndexBuilder.build_index_v1")
    expect(fetch).not_to be_nil
    expect(build).not_to be_nil
    expect(build).to be > fetch
  end

  # Nothing here zips: relaton/support's shared crawler.yml zips every
  # index*.yaml that changed and commits both files. A second zip written here
  # would differ byte for byte from the one CI commits.
  it "does not zip" do
    expect(source).not_to match(/require\s+["']zip["']|Zip::|system\(["']zip/)
  end
end
