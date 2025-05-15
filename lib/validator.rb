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

  def initialize(directory, logger, plog)
    @parent = Pathname.new(directory)
    @logger = logger
    @plog = plog
    @digest = nil
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
    if matches.length != 1 # There should be only one manifest file per dissertation dir
      ProgressLogging.err(@plog,
                          CustomError.new("Expected one manifest file, but got a different number. (Number of matches: #{matches.length})"))
      return false
    end
    manifest = matches.pop.basename.to_s

    # algorithm substr is present and is a valid hash format
    alg = manifest.match(MANIFEST_REGEX)[1]
    if alg.nil?
      @logger.warn 'Could not determine hashing algorithm from manifest.'
      ProgressLogging.warn(@plog,
                           'Could not determine hashing algorithm from manifest.')
      return false
    end
    begin
      init_manifest_digest(alg)
    rescue StandardError => e
      @logger.error "Failed to create Digest object from given algorithm. Error: #{e}"
      ProgressLogging.err(@plog, e,
                          "An error occurred determining the hashing algorithm. Got: #{alg} Expecting one of: #{ALLOWED_ALGS}")
      # We still want to run all validation checks--therefore, this is not a fatal error.
    end
    true
  end

  # Sets the @digest attribute to the corresponding hashing algorithm digest object
  def init_manifest_digest(alg)
    puts 'valid_manifest_algorithm()'
    raise CustomError, "Unexpected hashing algorithm '#{alg}" unless ALLOWED_ALGS.include?(alg)

    @digest = Object.const_get("Digest::#{alg.upcase}")
  end

  # file exists
  # matching date_time prefix
  def valid_items_csv?
    @logger.debug 'Validator#valid_items_csv(): Entry'
    expectation = "#{@parent}#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    ProgressLogging.warn(@plog, "Could not find yyyy_mm_items.csv file. Expected: #{expectation}.")
    false
  end

  # file exists
  # matching date_time prefix
  def valid_assets_csv?
    puts 'valid_assets_csv()'

    expectation = "#{@parent}#{@date_prefix_str}_assets.csv"
    return true if File.exist?("#{@parent}#{@date_prefix_str}_assets.csv")

    ProgressLogging.warn(@plog, "Could not find yyyy_mm_assets.csv file. Expected: #{expectation}.")
    false
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
