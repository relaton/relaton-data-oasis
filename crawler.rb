# frozen_string_literal: true

require 'fileutils'
require 'relaton/oasis/data_fetcher'

FileUtils.rm_rf('data')
FileUtils.rm(Dir.glob('index*'))

Relaton::Oasis::DataFetcher.fetch
