# frozen_string_literal: true

require 'digest'
require 'pathname'
require 'cul/preservation_utils'

# The validator class is capable of validating a yyyy_mm_dissertations/ directory
# contains all of the files and adheres to all validation rules
# @dissertation_dir : the yyyy_mm_dissertations/ directory under examination
# @manifest_filename:
# VALIDAITON RULES
# 1.  : All required files present
# 1.1 : The manifest file exists and has an accepted algorithm in it
# 1.2 : An yyyy_mm_items.csv file with a matching prefix exists
# 1.3 : An yyyy_mm_assets.csv file with a matching prefix exists
# 2.  : No undesireable characters are present in any of the file/directory names
# 3.  : All files listed in the manifest file are accounted for
# 3.1 : All files listed in the manifest exist in the downloaded temp directory
# 3.2 : All files in the downloaded temp directory (besides metadata files) are listed in the manifest
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
    @dissertation_dir = dissertations_directory # abs path to yyyy_mm_dissertations.temp
    @manifest_filename = ''
    @manifest_hash = {}
    @digest_class = nil
  end

  # The Starting point for the validations process
  # Runs each validation check and returns true if all of the validation checks passed
  # False otherwise
  def run_validations
    GsasSync::Logger.log_all("-- -- Validating files for #{@dissertation_dir.basename}/ -- --")
    @files_present = all_required_files_present?
    @no_bad_chars = no_undesirable_characters_in_file_paths?
    @valid_manifest = all_accounted_for_in_manifest?
    @checksums = valid_checksums?
    @files_present && @no_bad_chars && @valid_manifest && @checksums
  end

  # VALIDATION RULE 1 ##################################################################################################
  def all_required_files_present?
    GsasSync::Logger.stdout_logger.debug('Validator#all_required_files_present(): Entry')
    @date_prefix_str = @dissertation_dir.basename.to_s[0...DATE_PREFIX_LEN]
    valid = true
    valid &= valid_manifest_file?
    valid &= valid_items_csv?
    valid &= valid_assets_csv?
    valid &= File.directory? "#{@dissertation_dir}/data"
    log_validation_result(valid, 'All required files present')
    valid
  end

  # VALIDATION RULE 1.1
  def valid_manifest_file?
    GsasSync::Logger.stdout_logger.debug('Validator#valid_manifest_file?(): Entry')
    find_manifest_file

    # algorithm substr is present and is a valid hash format
    alg = @manifest_filename.match(MANIFEST_REGEX)[1]
    if alg.nil?
      raise GsasSync::Exceptions::ValidationError, 'Could not determine hashing algorithm from manifest file name'
    elsif !ALLOWED_ALGS.include?(alg)
      raise GsasSync::Exceptions::ValidationError, "Unexpected hashing algorithm '#{alg}'"
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
    matches = @dissertation_dir.children.select do |child|
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

    @digest_class = Object.const_get("Digest::#{alg.upcase}")
  end

  # VALIDATION RULE 1.2
  def valid_items_csv?
    GsasSync::Logger.stdout_logger.debug 'Validator#valid_items_csv(): Entry'
    expectation = "#{@dissertation_dir}/#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_items.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 1.3
  def valid_assets_csv?
    GsasSync::Logger.stdout_logger.debug 'valid_assets_csv()'

    expectation = "#{@dissertation_dir}/#{@date_prefix_str}_assets.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_assets.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 2 ##################################################################################################
  # This method recursively checks nested directories, visiting each item
  # and logging any errors that are encountered in the progress log
  def no_undesirable_characters_in_file_paths?(directory = @dissertation_dir)
    valid = valid_file_paths_recursive(directory)
    log_validation_result(valid, 'No files or directories contain undesirable characters')
    valid
  rescue StandardError => e
    GsasSync::Logger.log_all_error(
      'An unexpected error ocurred while validating filepaths for undesirable characters.', e
    )
    false
  end

  # Validate each file and directory recursively, logging any that fail the validation
  # to the progress log
  def valid_file_paths_recursive(directory = @dissertation_dir)
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

  # VALIDATION RULE 3 ##################################################################################################
  def all_accounted_for_in_manifest?
    GsasSync::Logger.stdout_logger.debug 'all_accounted_for_in_manifest?() Entry'
    return false unless valid_manifest_and_digest_instance_variables?

    build_manifest_hash
    valid = files_in_manifest_exist?
    valid &= all_downloaded_files_in_manifest?
    log_validation_result(valid, 'All files in manifest are accounted for')
    valid
  end

  # Populates the @manifest_hash based on the contents of the @manifest_filename
  # Hash structure: { 'file_path' => 'checksum_value', ... }
  def build_manifest_hash
    GsasSync::Logger.stdout_logger.debug('Validator#build_manifest_hash: Entry')
    File.open("#{@dissertation_dir}/#{@manifest_filename}", 'r') do |file_handle|
      file_handle.each_line do |line|
        checksum, file = line.split
        file = "#{@dissertation_dir}/#{file.delete_prefix('./')}"
        @manifest_hash[file] = checksum
      end
    end
  end

  # VALIDATION RULE 3.1
  # Returns false if any of the files listed in the manifest are not present in the downloaded @dissertation_dir
  # Removes entries for any non-existent files from the @manifest_hash
  def files_in_manifest_exist?
    GsasSync::Logger.stdout_logger.debug('Validator#files_in_manifest_exist?: Entry')
    result = true
    @manifest_hash.each_key do |file|
      next if File.exist?(file)

      GsasSync::Logger.log_all_warn("‼️ The file #{file} is listed in the manifest file but does not exist in the downloaded directory") # rubocop:disable Layout/LineLength
      @manifest_hash.delete(file)
      result = false
    end
    result
  end

  # VALIDATION RULE 3.2
  # returns true if all files in the @dissertation_dir directory are listed in the manifest file
  # TODO : We could use this same logic in #files_in_manifest_exist? ; it's just an array difference the other direction
  # (manifest_files_array - downloaded_files_array) -- this may be a performant refactor to do in the future.
  def all_downloaded_files_in_manifest?
    GsasSync::Logger.stdout_logger.debug('Validator#any_files_not_in_manifest?: Entry')
    raise GsasSync::Exceptions::ValidationError, 'manifest hash is undefined' if @manifest_hash.nil?

    downloaded_files_array = recursive_files_array(@dissertation_dir).sort
    manifest_files_array = @manifest_hash.keys.sort

    return true if downloaded_files_array == manifest_files_array

    diff = downloaded_files_array - manifest_files_array
    GsasSync::Logger.log_all_warn("‼️ The following file(s) were downloaded, but are not listed in the manifest: #{diff}") # rubocop:disable Layout/LineLength
    false
  end

  # Returns array containing filenames (as strings) of every file under the given parent directory, recursively
  # including nested directory's files
  def recursive_files_array(parent = @dissertation_dir)
    array = []
    parent.each_child do |child|
      if child.directory?
        next if child.children.empty? # Skip empty directories

        array.push(*recursive_files_array(child))
      else
        next if metadata_file?(child.basename.to_s) # Skip metadata files

        array.push(child.to_s)
      end
    end
    array
  end

  # Returns true if the given filename is a metadata file; either an items csv, assets csv, or manifest file
  def metadata_file?(filename)
    GsasSync::Logger.stdout_logger.debug('Validator#metadata_file?: Entry')
    if ["#{@date_prefix_str}_items.csv", "#{@date_prefix_str}_assets.csv", @manifest_filename].include?(filename)
      return true
    end

    false
  end

  # Returns false and logs warning if either the @manifest_file or @digest_class instance variables are not set
  # This would indicate that certain validation steps cannot be run
  def valid_manifest_and_digest_instance_variables?
    if @manifest_filename == ''
      GsasSync::Logger.log_all_warn('Invalid manifest file. Unable to validate that all files in manifest are present.')
      return false
    end
    if @digest_class.nil?
      GsasSync::Logger.log_all_warn('No valid checksum algorithm. Unable to validate that all files in manifest are present.') # rubocop:disable Layout/LineLength
      return false
    end
    true
  end

  # VALIDATION RULE 4 ##################################################################################################
  def valid_checksums?
    unless valid_manifest_and_digest_instance_variables?
      GsasSync::Logger.log_all_warn('Invalid manifest file or checksum algorithm. Unable to validate checksums.')
      return false
    end
    valid = true
    @manifest_hash.each do |file_path, checksum|
      next if @digest_class.file(file_path).hexdigest == checksum

      GsasSync::Logger.log_all_warn("Checksum does not match manifest value: #{file_path}")
      valid = false
    end
    log_validation_result(valid, 'All checksum values match manifest')
    valid
  end

  private

  def log_validation_result(valid, message)
    if valid
      GsasSync::Logger.progress("-- ✅ Validation Success: #{message} --")
    else
      GsasSync::Logger.progress("-- ❌ Validation Failure: #{message} --")
    end
    # TODO: consider returning valid here, then rename to log_validation_result_and_return_value
    # con : this may make testing a little awkward; mock the method to have it return whatever was passed as first param
  end
end
