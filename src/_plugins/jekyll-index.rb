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

    def create_doc(item)
      doc = Jekyll::Document.new(item[:file], site: @site, collection: @site.collections['posts'])
      hash = YAML.load_file(item[:file])
      doc.content = hash['title'].first['content']
      doc.merge_data! data(item, hash)
      doc
    end

    def data(item, hash)
      date = date(hash)
      stage = hash.dig('docstatus', 'stage', 'value') || date['type']
      yaml_ref = "#{@site.config['jekyll-index']['baseurl']}#{item[:file]}"
      {
        'ref' => reference(item, hash), 'doctype' => hash['doctype'], 'stage' => stage, 'date' => date['value'],
        'yaml_ref' => yaml_ref
      }
    end

    def date(hash)
      hash['date'].find { |d| d['type'] == 'published' } || hash['date'].first
    end

    def reference(item, hash)
      if @site.config['jekyll-index']['add_type_to_reference']
        type = hash['docid'].find { |id| id['primary'] }['type']
        "#{type} #{item[:id]}"
      else
        item[:id]
      end
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
