module JekyllIndex
  class Generator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      puts "Generating index..."
      Jekyll.logger.info "Generating index..."
      File.write "jekyll-index.log", "Generating index..."
      raise "No index template found" unless site.layouts.key? 'index'
    end
  end
end
