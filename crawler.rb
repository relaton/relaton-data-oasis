# frozen_string_literal: true

require 'fileutils'
require 'relaton_oasis'

FileUtils.rm_rf('data')
FileUtils.rm_f('index.yaml')

RelatonOasis::DataFetcher.fetch

FileUtils.cp('index.yaml', 'src/_data/')
