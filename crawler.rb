# frozen_string_literal: true

require 'fileutils'
require 'relaton_oasis'

FileUtils.rm_rf('data')

RelatonOasis::DataFetcher.fetch

system("git add data/* flag.txt")
