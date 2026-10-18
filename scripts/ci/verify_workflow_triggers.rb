#!/usr/bin/env ruby

require 'yaml'

workflow_path = ARGV.fetch(0, '.github/workflows/mobile-ci.yml')

begin
  workflow = YAML.safe_load(File.read(workflow_path), aliases: false)
rescue Psych::SyntaxError => error
  warn "Invalid workflow YAML: #{error.message}"
  exit 1
end

unless workflow.is_a?(Hash)
  warn 'Mobile CI workflow must be a YAML mapping.'
  exit 1
end

# Psych follows YAML 1.1 and may parse the plain key `on` as boolean true.
triggers = workflow.key?('on') ? workflow['on'] : workflow[true]
unless triggers.is_a?(Hash)
  warn 'Mobile CI must declare exactly one pull_request trigger.'
  exit 1
end

normalized_triggers = triggers.transform_keys(&:to_s)
unless normalized_triggers.keys == ['pull_request']
  warn 'Mobile CI must declare exactly one pull_request trigger and no bypass triggers.'
  exit 1
end

pull_request_config = normalized_triggers['pull_request']
unless pull_request_config.nil? || (pull_request_config.is_a?(Hash) && pull_request_config.empty?)
  warn 'The pull_request trigger must not contain paths, paths-ignore, or other filters.'
  exit 1
end


puts 'Mobile CI trigger validation passed.'
