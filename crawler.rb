# frozen_string_literal: true

require 'fileutils'
require 'relaton_oasis'

FileUtils.rm_rf('data')
FileUtils.rm(Dir.glob('index*'))

RelatonOasis::DataFetcher.fetch

FileUtils.cp('index.yaml', 'src/_data/')

system 'zip index-v1.zip index-v1.yaml'
system 'git add index-v1.zip index-v1.yaml'
