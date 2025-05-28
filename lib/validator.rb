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

  attr_accessor :files_present, :no_bad_chars, :good_manifest, :chucksums

  def initialize(directory)
    @parent = Pathname.new(directory)
    @manifest_filename = ''
    @digest_class = nil
  end

  # we want to be able to list ALL of the validation errors so that ALL errors can be
  # addressed by GSAS at once. Otherwise, there could be a situation where they address an issue, try to transfer again,
  # and it fails again for a novel reason -- better if they can know all the errors at one time.
  def run_validations
    # rescue the errors within these methods, but allow all four to execute
    GsasSync::Logger.log_all("-- -- Validating files for #{@parent} -- --")
    @files_present = all_required_files_present?
    @no_bad_chars = no_undesirable_characters_in_file_paths?
    @valid_manifest = all_accounted_for_in_manifest?
    @checksums = valid_checksums?
    @files_present && @no_bad_chars && @valid_manifest && @checksums
  end

  # manifest-{alg}.txt is present
  # yyyy_mm_items.csv is present
  # yyyy_mm_assets.csv is present
  # data directory is present
  # VALIDATION RULE 1
  def all_required_files_present?
    GsasSync::Logger.stdout_logger.debug('Validator#all_required_files_present(): Entry')
    @date_prefix_str = @parent.basename.to_s[0...DATE_PREFIX_LEN]
    valid = true
    valid &= valid_manifest_file?
    valid &= valid_items_csv?
    valid &= valid_assets_csv?
    valid &= File.directory? "#{@parent}data"
    GsasSync::Logger.progress '-- Validation Success: All required files present --' if valid
    valid
  end

  # side effect: if the manifest is present, sets @manifest_csv_fd and @digest attributes
  # manifest is valid if:
  #   - a manifest file exists
  #   - algorithm substr is present
  #   - algorithm is legit
  def valid_manifest_file?
    GsasSync::Logger.stdout_logger.debug('Validator#valid_manifest_file?(): Entry')
    find_manifest_file

    if @manifest_filename == '' # TODO: is this case possible? Wouldn't an exception be raised before this check?
      GsasSync::Logger.log_all_warn 'An error ocurred loading the manifest file'
      return false
    end

    # algorithm substr is present and is a valid hash format
    alg = @manifest_filename.match(MANIFEST_REGEX)[1]
    if alg.nil?
      GsasSync::Logger.log_all_warn('Could not determine hashing algorithm from manifest')
      return false
    end

    init_manifest_digest(alg)
    true
  rescue StandardError => e
    GsasSync::Logger.log_all_error('Failed to validate manifest file', e)
    false
  end

  # Sets the @digest attribute to the corresponding hashing algorithm digest object
  def find_manifest_file
    GsasSync::Logger.stdout_logger.debug 'find_manifest_file(): Entry'
    # temp\**YYYY_MM_dissertations**\YYYY_MM_manifest-{algorithm}.txt
    # # file is present
    matches = @parent.children.select do |child|
      child.basename.to_s.match?(MANIFEST_REGEX)
    end
    if matches.length != 1 # There should be only one manifest file per dissertation dir
      raise GsasSync::Exceptions::ValidationError,
            "Expected one manifest file, but got a different number. (Number of matches: #{matches.length})"
    end
    @manifest_filename = matches.pop.basename.to_s
  end

  # Can raise an exception if unable to make a valid Digest Object
  def init_manifest_digest(alg)
    GsasSync::Logger.stdout_logger.debug 'init_manifest_digest(): Entry'
    unless ALLOWED_ALGS.include?(alg)
      raise GsasSync::Exceptions::ValidationError,
            "Unexpected hashing algorithm '#{alg}'"
    end

    @digest_class = Object.const_get("Digest::#{alg.upcase}")
  end

  # file exists
  # matching date_time prefix
  def valid_items_csv?
    GsasSync::Logger.stdout_logger.debug 'Validator#valid_items_csv(): Entry'
    expectation = "#{@parent}#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_items.csv file. Expected: #{expectation}.")
    false
  end

  # file exists
  # matching date_time prefix
  def valid_assets_csv?
    GsasSync::Logger.stdout_logger.debug 'valid_assets_csv()'

    expectation = "#{@parent}#{@date_prefix_str}_assets.csv"
    return true if File.exist?("#{@parent}#{@date_prefix_str}_assets.csv")

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_assets.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 2
  # Validate that each item in the given directory does not include undesireable characters
  # in its full file path (parent directories and basename).
  # This method recursively checks nested directories, visiting each item
  # and logging any errors that are encountered in the progress log
  def no_undesirable_characters_in_file_paths?(directory = @parent)
    valid = valid_file_paths_recursive
    if valid
      GsasSync::Logger.progress('-- Validation Success: No files or directories contain undesirable characters --')
    end
    valid
  rescue StandardError => e
    GsasSync::Logger.stdout_logger.log_all_error(
      'An unexpected error ocurred while validating filepaths for undesirable characters.', e
    )
    false
  end

  # Validate each file and directory recursively, logging any that fail the validation
  # to the progress log
  # This is a recursive algorithm
  def valid_file_paths_recursive(directory = @parent)
    valid = Cul::PreservationUtils::FilePath.valid_file_path? directory.basename
    log_validated_filepath(directory, valid)
    directory.each_child do |f|
      if File.directory? f
        valid &= valid_file_paths_recursive f
      else
        valid_file = Cul::PreservationUtils::FilePath.valid_file_path? f.basename
        log_validated_filepath(f, valid_file)
        valid &= valid_file
      end
    end
    valid
  end

  def log_validated_filepath(fp, valid) # rubocop:disable Naming/MethodParameterName
    if valid
      GsasSync::Logger.log_all "Validated for undesirable characters: #{fp.basename}"
    else
      GsasSync::Logger.log_all_warn "Invalid characters found: #{fp.basename}"
    end
  end

  # VALIDATION RULE 3
  def all_accounted_for_in_manifest?
    GsasSync::Logger.stdout_logger.debug 'all_accounted_for_in_manifest?() Entry'
    if @manifest_filename == ''
      GsasSync::Logger.log_all_warn('Invalid manifest file. Unable to validate that all files in manifest are present.')
      return false
    end

    if @digest_class.nil?
      GsasSync::Logger.log_all_warn('No valid checksum algorithm. Unable to validate that all files in manifest are present.')
      puts 'no digest class!'
      return false
    end

    valid = true
    array = []
    @manifest_hash = {}
    File.open("#{@parent}#{@manifest_filename}", 'r') do |f|
      array = f.readlines
    end
    array.each do |line|
      checksum, file = line.split
      file = "#{@parent}#{file.delete_prefix('./')}"
      unless File.exist?(file)
        valid = false
        continue
      end
      @manifest_hash[file] = checksum
    end

    GsasSync::Logger.progress('-- Validation Success: All files in manifest are accounted for --') if valid
    valid
  end

  # VALIDATION RULE 4
  def valid_checksums?
    unless @valid_manifest # TODO: Log
      GsasSync::Logger.log_all_warn('No valid manifest file. Unable to validate checksums.')
      return false
    end
    valid = true
    @manifest_hash.each do |file_path, checksum|
      next unless @digest_class.file(file_path).hexdigest != checksum

      GsasSync::Logger.log_all_warn("Checksum does not match manifest value: #{file_path}")
      valid = false
    end

    GsasSync::Logger.progress('-- Validation Success: All checksum values match manifest --') if valid
    valid
  end
end
