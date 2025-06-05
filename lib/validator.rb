# frozen_string_literal: true

require 'digest'
require 'pathname'
require 'cul/preservation_utils'

# The validator class is capable of validating a yyyy_mm_dissertations/ directory
# contains all of the files and adheres to all validation rules
# @parent : the yyyy_mm_dissertations/ directory under examination
# @manifest_filename:
# manifest-{alg}.txt is present
# yyyy_mm_items.csv is present
# yyyy_mm_assets.csv is present
# data directory is present
# VALIDAITON RULES
# 1.  : All required files present
# 1.1 : The manifest file exists and has an accepted algorithm in it
# 1.2 : An yyyy_mm_items.csv file with a matching prefix exists
# 1.3 : An yyyy_mm_assets.csv file with a matching prefix exists
# 2.  : No undesireable characters are present in any of the file/directory names
# 3.  : All files listed in the manifest file are present in the downloaded directory
# 4.  : The checksums listed for each file in the manifest match the checksums for what was downloaded
class Validator
  DATE_PREFIX_LEN = 7
  DISSERTATION_DIR_REGEX = /^\d{4}_\d{2}_dissertations$/
  MANIFEST_REGEX = /^manifest-([a-zA-Z0-9]+)\.txt$/
  ALLOWED_ALGS = %w[sha256 md5].freeze # TODO: update this list of expected Checksum algorithms as needed

  # Allow the caller to determine exactly what did and did not pass
  attr_reader :files_present, :no_bad_chars, :good_manifest, :chucksums

  # Params:
  #  - dissertations_directory: Pathname object representing a yyyy_mm_dissertations.temp directory
  def initialize(dissertations_directory)
    GsasSync::Logger.stdout_logger.debug('Validator#initialize(): Entry')
    @parent = dissertations_directory # yyyy_mm_dissertations # TODO : rename to something like "dissertation_dir_name" - parent implies this variable holds the parent of whatever we care about -- but it actually is the thing we care about.
    @manifest_filename = ''
    @digest_class = nil
  end

  # The Starting point for the validations process
  # Runs each validation check and returns true if all of the validation checks passed
  # False otherwise
  def run_validations
    GsasSync::Logger.log_all("-- -- Validating files for #{@parent.basename}/ -- --")
    @files_present = all_required_files_present?
    @no_bad_chars = no_undesirable_characters_in_file_paths?
    @valid_manifest = all_accounted_for_in_manifest?
    @checksums = valid_checksums?
    @files_present && @no_bad_chars && @valid_manifest && @checksums
  end

  # VALIDATION RULE 1
  def all_required_files_present?
    GsasSync::Logger.stdout_logger.debug('Validator#all_required_files_present(): Entry')
    @date_prefix_str = @parent.basename.to_s[0...DATE_PREFIX_LEN]
    valid = true
    valid &= valid_manifest_file?
    valid &= valid_items_csv?
    valid &= valid_assets_csv?
    valid &= File.directory? "#{@parent}/data"
    if valid
      GsasSync::Logger.progress '-- ✅ Validation Success: All required files present --'
    else
      GsasSync::Logger.progress '-- ️❌  Validation Failure: All required files present --'
    end
    valid
  end

  # VALIDATION RULE 1.1
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

  # Side effet: sets the @manifest_filename instance variable on success
  def find_manifest_file
    GsasSync::Logger.stdout_logger.debug 'find_manifest_file(): Entry'
    matches = @parent.children.select do |child|
      child.basename.to_s.match?(MANIFEST_REGEX)
    end
    if matches.length != 1 # There should be only one manifest file per dissertation dir
      raise GsasSync::Exceptions::ValidationError,
            "Expected one manifest file, but got a different number. (Number of matches: #{matches.length})"
    end
    @manifest_filename = matches.pop.basename.to_s
  end

  # Side effect: sets the @digest_class instance variable on success
  def init_manifest_digest(alg)
    GsasSync::Logger.stdout_logger.debug 'init_manifest_digest(): Entry'
    unless ALLOWED_ALGS.include?(alg)
      raise GsasSync::Exceptions::ValidationError,
            "Unexpected hashing algorithm '#{alg}'"
    end

    @digest_class = Object.const_get("Digest::#{alg.upcase}")
  end

  # VALIDATION RULE 1.2
  def valid_items_csv?
    GsasSync::Logger.stdout_logger.debug 'Validator#valid_items_csv(): Entry'
    expectation = "#{@parent}/#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_items.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 1.3
  def valid_assets_csv?
    GsasSync::Logger.stdout_logger.debug 'valid_assets_csv()'

    expectation = "#{@parent}/#{@date_prefix_str}_assets.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_assets.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 2
  # This method recursively checks nested directories, visiting each item
  # and logging any errors that are encountered in the progress log
  def no_undesirable_characters_in_file_paths?(directory = @parent)
    valid = valid_file_paths_recursive(directory)
    if valid
      GsasSync::Logger.progress('-- ✅ Validation Success: No files or directories contain undesirable characters --')
    else
      GsasSync::Logger.progress('-- ❌ Validation Failure: No files or directories contain undesirable characters --')
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
      GsasSync::Logger.stdout_logger.debug "✔️ Validated for undesirable characters: #{fp.basename}"
    else
      GsasSync::Logger.log_all_warn "‼️ Invalid characters found: #{fp.basename}"
    end
  end

  # VALIDATION RULE 3
  # This also builds the @manifest_hash map (filename => checksum)
  def all_accounted_for_in_manifest?
    GsasSync::Logger.stdout_logger.debug 'all_accounted_for_in_manifest?() Entry'
    return false unless valid_manifest_and_digest_instance_variables

    valid = true
    @manifest_hash = {}
    File.open("#{@parent}/#{@manifest_filename}", 'r') do |file_handle|
      file_handle.each_line do |line|
        checksum, file = line.split
        file = "#{@parent}/#{file.delete_prefix('./')}"
        unless File.exist?(file)
          valid = false
          next
        end
        @manifest_hash[file] = checksum
      end
    end
    if valid
      GsasSync::Logger.progress('-- ✅ Validation Success: All files in manifest are accounted for --')
    else
      GsasSync::Logger.progress('-- ❌ Validation Failure: All files in manifest are accounted for --')
    end
    valid
  end

  def valid_manifest_and_digest_instance_variables
    if @manifest_filename == ''
      GsasSync::Logger.log_all_warn('Invalid manifest file. Unable to validate that all files in manifest are present.')
      return false
    end
    if @digest_class.nil?
      GsasSync::Logger.log_all_warn('No valid checksum algorithm. Unable to validate that all files in manifest are present.')
      return false
    end
    true
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
    if valid
      GsasSync::Logger.progress('-- ✅ Validation Success: All checksum values match manifest --')
    else
      GsasSync::Logger.progress('-- ❌  Validation Success: All checksum values match manifest --')
    end
    valid
  end
end
