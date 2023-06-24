module JekyllIndex
  #
  # JekyllIndex::Generator
  #
  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      @site = site
      collection.each { |item| site.posts.docs << create_doc(item) }
      site.site_payload['site']['favicon'] = site.config['jekyll-index']['favicon']
    end

    private

    def create_doc(item) # rubocop:disable Metrics/AbcSize
      hash = YAML.load_file(item[:file])
      doctype = hash['doctype']
      date = hash['date'].find { |d| d['type'] == 'published' } || hash['date'].first
      stage = hash.dig('docstatus', 'stage', 'value') || date['type']
      doc = Jekyll::Document.new(item[:file], site: @site, collection: @site.collections['posts'])
      doc.content = hash['title'].first['content']
      yaml_ref = "#{@site.config['jekyll-index']['baseurl']}#{item[:file]}"
      doc.merge_data!({ 'ref' => item[:id], 'doctype' => doctype, 'stage' => stage, 'date' => date['value'], "yaml_ref" => yaml_ref })
      doc
    end

    def collection
      return @collection if defined? @collection

      @collection = index.map do |item|
        item
      end
    end

    def index
      YAML.load_file(@site.config['jekyll-index']['source'])
    end
  end
end
