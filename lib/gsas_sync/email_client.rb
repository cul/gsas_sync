# frozen_string_literal: true

class GsasSync
  class EmailClient
    FAILURE_SUBJECT = 'Failure: Gsas Sync process could not complete the file transfer'
    FAILURE_BODY = 'The Gsas Sync process failed to complete the transfer process. A log file has been attached "\
    "detailing what occurred. Please address any validation errors and contact the DLST to attempt the transfer " \
    "again. The files were not deleted on the remote transfer server.'

    def initialize
      @server = GsasSync::Config.mail_server['host']
      @port = GsasSync::Config.mail_server['port']
      @sender = GsasSync::Config.mail_server['sender_address']
      @recipients = GsasSync::Config.mail_server['recipients']
      puts "recips #{@recipients}"
      @log_file = "#{GsasSync::Config.logs_directory}progress.log"
      init_mail_client
    end

    # Configures the Mail gem library to use smtp and use our smtp server
    def init_mail_client
      server = @server
      port = @port
      Mail.defaults do
        delivery_method :smtp, address: server, port: port
      end
    end

    def send_failure_email_all
      subject = FAILURE_SUBJECT
      body = FAILURE_BODY
      @recipients.each { |email| send_failure_email(email, subject, body) }
    end

    def send_failure_email(recipient, subject, body)
      logfile = "#{FileUtils.pwd}/#{@log_file}"
      puts logfile
      sender = @sender # lexical scope needed for Mail.deliver block; use local variables
      log_file = @log_file
      Mail.deliver do
        from sender
        to recipient
        subject subject
        body body
        add_file logfile # "#{FileUtils.pwd}/#{log_file}"
      end
      # TODO: log
    end
  end
end
