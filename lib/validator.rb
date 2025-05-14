# frozen_string_literal: true

require 'digest'
require 'pathname'
require 'cul/preservation_utils'

# The validator class is capable of validating a yyyy_mm_dissertations/ directory
# contains all of the files and adheres to all validation rules
# @parent : the yyyy_mm_dissertations/ directory under examination
class Validator
  DATE_PREFIX_LEN = 7
  DISSERTATION_DIR_REGEX = /^\d{4}_\d{2}_dissertations$/
  MANIFEST_REGEX = /^manifest-([a-zA-Z0-9]+)\.txt$/
  ALLOWED_ALGS = %w[sha256 md5]
  # ITEMS_REGEX = /^\d{4}_\d{2}_items\.csv$/ # todo, well this could be done with File.exist? actually, because we would know what we are looking for at that point!!

  def initialize(directory, logger, elog)
    @parent = Pathname.new(directory)
    @logger = logger
    @elog = elog
  end

  # manifest-{alg}.txt is present
  # yyyy_mm_items.csv is present
  # yyyy_mm_assets.csv is present
  # data directory is present
  # VALIDATION RULE 1
  def all_required_files_present?
    @logger.debug('Validator#all_required_files_present(): Entry')
    @date_prefix_str = @parent.basename.to_s[0...DATE_PREFIX_LEN]
    return false unless valid_manifest_file?
    return false unless valid_items_csv?
    return false unless valid_assets_csv?
    return false unless File.directory?("#{@parent}data")

    true
  end

  # side effect: if the manifest is present, sets @manifest_csv_fd attribute
  # manifest is valid if:
  #   - a manifest file exists
  #   - algorithm substr is present
  #   - algorithm is legit
  def valid_manifest_file?
    @logger.debug('Validator#valid_manifest_file?(): Entry')
    # temp\**YYYY_MM_dissertations**\YYYY_MM_manifest-{algorithm}.txt
    # # file is present
    matches = @parent.children.select do |child|
      child.basename.to_s.match?(MANIFEST_REGEX)
    end
    return false if matches.length != 1 # There should be only one manifest file per dissertation dir

    manifest = matches.pop.basename.to_s

    # algorithm substr is present and is a valid hash format
    alg = manifest.match(MANIFEST_REGEX)[1]
    return false if alg.nil? || !valid_manifest_algorithm?(alg)

    true
  end

  # Sets the @digest attribute to the corresponding hashing algorithm digest object
  # Returns false on failure
  def valid_manifest_algorithm?(alg)
    puts 'valid_manifest_algorithm()'
    puts alg
    begin
      raise StandardError.new('Fake error')
      @digest = Object.const_get("Digest::#{alg.upcase}")
      true
    rescue LoadError => e
      @logger.fatal "Failed to create Digest object from given algorithm. Error: #{e}"
      @elog << ErrorHandling.elog_msg("Could not verify the manifest file while performing validations. An error occurred determining the hashing algorithm.\nGot: #{alg}\nExpecting one of: #{ALLOWED_ALGS}")
      raise StandardError.new('Must raise this') # TODO: YOU ARE HERE (WEDNESDAY, 5.14)
      false # ?
    end
  end

  # file exists
  # matching date_time prefix
  def valid_items_csv?
    @logger.debug 'Validator#valid_items_csv(): Entry'
    expectation = "#{@parent}#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    false # TODO: determine the nature of the error
  end

  # file exists
  # matching date_time prefix
  def valid_assets_csv?
    puts 'valid_assets_csv()'

    expectation = "#{@parent}#{@date_prefix_str}_assets.csv"
    puts expectation
    return true if File.exist?("#{@parent}#{@date_prefix_str}_assets.csv")

    false # TODO: determine the nature of the error
  end

  def undesirable_characters_in_file_paths?
    true # TODO: implement
  end

  def all_accounted_for_in_manifest?
    true # TODO: implement
  end

  def valid_checksums?
    true # TODO: implement
  end

  def init_digest(alg)
  end
end
