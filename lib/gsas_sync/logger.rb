# frozen_string_literal: true

require 'time'

# GsasSync::Logger controls all logging that occurs while the script is executing.
# There are two types of logs: the standard out logger (stdout_logger) and the
# progress logger (progress_logger). stdout_logger logs messages related to the
# execution of the script itself to the standard output of the machine executing the
# script. The progress_logger writes its logs to a .log file and it is more concerned
# with which steps in the download and verification processes actually succeed or
# fail; the progress log file that is created will be sent to the relevant parties
# when the transfer process succeeds or fails.
# The class follows the singleton pattern, ensuring that there is only ever one
# instance of either the stdout_logger or progress_logger while the script is executing.
class GsasSync::Logger
  MAX_NUM_LOG_FILES = 10
  LOG_FILE_REGEX = /(\d{12})-progress\.log$/ # YYMMDDhhmmss-progress.log
  TIME_FORMAT_STR = '%y%m%d%H%M%S'

  class << self
    attr_accessor :stdout_log_level # This should be set to the value captured by ArgParser

    def stdout_logger
      @stdout_logger ||= init_stdout_logger
    end

    def progress_log
      @progress_log ||= init_progress_log
    end

    def log_all(message)
      stdout_logger.info(message)
      progress_log << "#{time_prefix}\t #{message}\n" unless @progress_log.closed?
    end

    def log_all_fatal(message)
      stdout_logger.fatal(message)
      progress_log << pl_fatal(message) unless @progress_log.closed?
    end

    def log_all_error(message, err)
      stdout_logger.warn(message)
      stdout_logger.warn(err)
      progress_log << pl_error(message, err) unless @progress_log.closed?
    end

    def log_all_warn(message)
      stdout_logger.warn(message)
      progress_log << pl_warn(message) unless @progress_log.closed?
    end

    def begin_step(title, description = '')
      stdout_logger.info("Step: #{@progress_step}.) #{title}#{' -- ' unless description.empty?}#{description}")
      progress_log << pl_begin_step(@progress_step, title, description)
      @progress_step += 1
    end

    def progress(message)
      progress_log << "#{time_prefix}\t#{message}\n" unless @progress_log.closed?
    end

    def progress_log_dir_contents(directory, message = '')
      return if @progress_log.closed?

      progress(message.empty? ? "Contents of '#{directory}' directory:" : message)
      Dir.glob('**/*', base: directory).each do |child|
        progress_log << "\t\t - #{child}\n"
      end
    end

    def progress_log_append(message)
      return progress(message) unless @progress_log.closed?

      filepath = Pathname.new("#{GsasSync::Config.logs_directory}progress.log")
      File.open(filepath, 'a') do |file|
        file << "#{time_prefix}\t#{message}\n"
      end
    end

    def close_progress_log_file
      @progress_log&.close
    end

    def log_file_name
      @pathname.basename
    end

    private

    # Creates a new progress log file in the location defined in the configuration
    # Returns the open log file.
    # N.B. The progress log file must be closed with close_progress_log_file before the program terminates
    def init_progress_log
      @progress_step = 1
      @pathname = Pathname.new("#{GsasSync::Config.logs_directory}/#{generate_log_file_name}")
      rotate_logs
      FileUtils.mkdir(@pathname.dirname) unless File.directory?(@pathname.dirname)
      File.open(@pathname, 'w')
    end

    # Generates a log file name based on the current time
    # Format: YYMMDDhhmmss-progress.log
    def generate_log_file_name
      name = "#{Time.now.strftime(TIME_FORMAT_STR)}-progress.log"
      if File.exist? "#{GsasSync::Config.logs_directory}/#{name}" # Avoid naming collisions
        sleep(1)
        return generate_log_file_name
      end
      name
    end

    # Deletes the oldest log file if there are MAX_NUM_LOG_FILES log files
    def rotate_logs
      logs_dir = Pathname.new("#{FileUtils.pwd}/#{GsasSync::Config.logs_directory}")
      children = logs_dir.children
      return if children.length < MAX_NUM_LOG_FILES

      oldest = children.first # Arbitrary
      logs_dir.children.each do |child|
        next if child == oldest

        oldest = child if older?(child, oldest)
      end
      puts "rotating logs: deleting #{oldest.basename}"
      oldest.delete
    end

    # Returns true if the child is determined to be older than the target
    # child and target are Pathname objects
    def older?(child, target)
      child_time_stamp = Time.strptime(LOG_FILE_REGEX.match(child.basename.to_s)[1], TIME_FORMAT_STR)
      target_time_stamp = Time.strptime(LOG_FILE_REGEX.match(target.basename.to_s)[1], TIME_FORMAT_STR)
      res = nil
      puts "IN OLDER? - comparing #{child_time_stamp} <=> #{target_time_stamp}"
      p child_time_stamp
      p target_time_stamp
      case child_time_stamp <=> target_time_stamp
      when -1 then res = child_time_stamp
      when 1 then res = target_time_stamp
      when 0 then raise 'Unknown error occurred: somehow, two log files have the same exact timestamp...'
      end
      puts "---> #{res}"
      res
    end

    def init_stdout_logger
      raise GsasSync::Exceptions::GsasError, 'Standard out log level must be set' if @stdout_log_level.nil?

      @stdout_logger = Logger.new($stdout, stdout_log_level)
      format_logger
      @stdout_logger
    end

    # Called on the result of Logger.new() to apply custom formatting
    def format_logger
      stdout_logger.formatter = proc do |severity, datetime, progname, msg|
        severity_str = rainbowize_severity_str(severity)
        datetime_str = Rainbow(datetime).silver.faint
        progname_str = Rainbow(progname).cyan.bright
        "#{severity_str}\t(#{datetime_str}) - #{progname_str} : #{msg}\n"
      end
    end

    def rainbowize_severity_str(str)
      res = Rainbow(" #{str} ").bright
      case str
      when 'DEBUG' then res.blue.bg(:white)
      when 'INFO'then res.green.bg(:white)
      when 'WARN'then res.bg(:yellow)
      when 'ERROR'then res.red.bg(:yellow)
      when 'FATAL'then res.white.bg(:red)
      end
    end

    def time_prefix
      "[#{Time.now.strftime('%Y %m %e - %H:%M:%S::%L')}]"
    end

    def pl_error(msg, err)
      "#{time_prefix}\tA problem occurred and error was encountered, but execution will continue (for now)...\n" \
        "#{time_prefix}#{"\t\tError: #{err}" unless err.nil?}\n" \
        "#{time_prefix}#{"\t\tMessage: #{msg}" unless msg.empty?}\n" \
    end

    def pl_warn(msg = '')
      "#{time_prefix}\t A problem occurred, but execution will continue (for now)...\n" \
        "#{"#{time_prefix}\t\tMessage: #{msg}" unless msg.empty?}\n" \
    end

    def pl_fatal(msg = '')
      "#{time_prefix}\t A fatal error occurred:\n" \
        "#{"#{time_prefix}\t\tMessage: #{msg}" unless msg.empty?}\n"
    end

    def pl_begin_step(step, title, desc = '')
      "=======================#{time_prefix}=======================\n" \
      "#{time_prefix} Step: #{step}.) #{title}#{' -- ' unless desc.empty?}#{desc}\n"
    end
  end
end
