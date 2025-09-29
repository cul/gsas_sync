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
# 4.1 : The checksums listed for each file in the manifest match the checksums for what was downloaded
# 4.2 : Each checksum listed in the manifest file is unique
class Validator
  DATE_PREFIX_LEN = 7
  DISSERTATION_DIR_REGEX = /^\d{4}_\d{2}_dissertations$/
  MANIFEST_REGEX = /^manifest-([a-zA-Z0-9]+)\.txt$/
  ALLOWED_ALGS = %w[sha256 md5].freeze # TODO: update this list of expected Checksum algorithms as needed

  # Allow the caller to determine exactly what did and did not pass
  attr_reader :files_present, :no_bad_chars, :valid_manifest, :checksums

  # Params:
  #  - dissertations_directory: Pathname object representing a yyyy_mm_dissertations.temp directory
  def initialize(dissertations_directory)
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
    find_manifest_file!

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
  def find_manifest_file!
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
    @digest_class = Object.const_get("Digest::#{alg.upcase}")
  end

  # VALIDATION RULE 1.2
  def valid_items_csv?
    expectation = "#{@dissertation_dir}/#{@date_prefix_str}_items.csv"
    return true if File.exist?(expectation)

    GsasSync::Logger.log_all_warn("Could not find yyyy_mm_items.csv file. Expected: #{expectation}.")
    false
  end

  # VALIDATION RULE 1.3
  def valid_assets_csv?
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
    return false unless valid_manifest_and_digest_instance_variables?

    build_manifest_hash
    valid = no_metadata_files_in_manifest?
    valid &= files_in_manifest_exist_in_data_dir?
    valid &= all_downloaded_files_in_manifest?
    log_validation_result(valid, 'All files in manifest are accounted for')
    valid
  end

  # Populates the @manifest_hash based on the contents of the @manifest_filename
  # Hash structure: { 'file_path' => 'checksum_value', ... }
  def build_manifest_hash
    File.open("#{@dissertation_dir}/#{@manifest_filename}", 'r') do |file_handle|
      file_handle.each_line do |line|
        checksum, file = line.split
        file = "#{@dissertation_dir}/#{file.delete_prefix('./')}"
        @manifest_hash[file] = checksum
      end
    end
  end

  # VALIDATION RULE 3.1
  # Returns true if there are no assets or items csv metadata files listed in the
  # manifest file (only non-metadata files nested under data/ should be there).
  # Checks each file listed in the manifest. Removes any metadata files from the manifest hash.
  def no_metadata_files_in_manifest?
    metadata_files = @manifest_hash.keys.select { |path| metadata_file? File.basename(path) }

    metadata_files.each do |path|
      GsasSync::Logger.log_all_warn("‼️ The #{File.basename(path)} metadata file should not be included in the manifest.") # rubocop:disable Layout/LineLength
      @manifest_hash.delete path
    end

    metadata_files.empty?
  end

  # VALIDATION RULE 3.2
  # Returns false if any of the files listed in the manifest are not present in the downloaded @dissertation_dir/data
  # directory.
  # Removes entries for any non-existent files and files not nested under data/ from the @manifest_hash
  def files_in_manifest_exist_in_data_dir?
    missing_files = @manifest_hash.keys.reject { |file| File.exist?(file) && file.split('/').include?('data') }

    missing_files.each do |file|
      GsasSync::Logger.log_all_warn("‼️ The file '#{file}' is listed in the manifest file but does not exist in the downloaded data/ directory") # rubocop:disable Layout/LineLength
      @manifest_hash.delete file
    end

    missing_files.empty?
  end

  # VALIDATION RULE 3.3
  # returns true if all files in the @dissertation_dir/data directory are listed in the manifest file
  def all_downloaded_files_in_manifest?
    raise GsasSync::Exceptions::GsasError, 'manifest hash is undefined' if @manifest_hash.nil?

    downloaded_files_array = recursive_files_array(@dissertation_dir)
    # Any file that is not a key in the hash is unlisted
    unlisted_files = downloaded_files_array.reject { |path| @manifest_hash.key? path }

    unlisted_files.each do |path|
      GsasSync::Logger.log_all_warn("‼️ The following file was downloaded, but is not listed in the manifest: #{path}")
    end

    unlisted_files.empty?
  end

  # Returns array containing filenames (as strings) of every file under the given parent directory, recursively
  # including nested directory's files -- EXCLUDING any metadata files.
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
    ["#{@date_prefix_str}_items.csv", "#{@date_prefix_str}_assets.csv", @manifest_filename].include?(filename)
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

    valid = checksums_match?
    valid &= checksums_unique?

    log_validation_result(valid, 'All checksum values match manifest')
    valid
  end

  # Returns true if the checksums listed in the manifest file are all unique among one another
  def checksums_unique?
    hash_copy = {}
    result = true
    @manifest_hash.each do |filepath, checksum|
      if hash_copy.key?(checksum)
        GsasSync::Logger.log_all_warn("The checksums listed in the manifest file are not unique; a duplicate file may have been uploaded. Suspicious files: #{filepath} & #{hash_copy[checksum]}.") # rubocop:disable Layout/LineLength
        result = false
        next
      end

      hash_copy[checksum] = filepath
    end

    result
  end

  # Returns true if the checksums listed in the manifest match the calculated checksums of the
  # files that were downloaded
  def checksums_match?
    valid = true
    @manifest_hash.each do |file_path, checksum|
      next if hex_checksums_match?(@digest_class.file(file_path).hexdigest, checksum)

      GsasSync::Logger.log_all_warn("Checksum does not match manifest value: #{file_path}")
      valid = false
    end
    valid
  end

  def hex_checksums_match?(sum1, sum2)
    sum1.upcase == sum2.upcase
  end

  private

  def log_validation_result(valid, message)
    if valid
      GsasSync::Logger.progress("-- ✅ Validation Success: #{message} --")
    else
      GsasSync::Logger.progress("-- ❌ Validation Failure: #{message} --")
    end
  end
end
