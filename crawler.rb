# frozen_string_literal: true

require 'fileutils'
require 'relaton_oasis'

FileUtils.rm_rf('data')
FileUtils.rm(Dir.glob('index*'))

RelatonOasis::DataFetcher.fetch
