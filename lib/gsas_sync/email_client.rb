# frozen_string_literal: true

class GsasSync
  class EmailClient
    SUCCESS_SUBJECT = 'The Gsas Disseration Sync process succeeded'
    SUCCESS_BODY =  "The Gsas Sync process completed successfully and without error.\nThe uploaded dissertations and "\
    'related files were successfully downloaded from the remote transfer server to the local preservations directory.'\
    "\nA log detailing the steps involved and the files that were transfered is attached to this email.\nPlease "\
    "contact the DLST if you have any questions.\nThis script is configured to automatically run once a month"\
    ' -- see you next time!'
    FAILURE_SUBJECT = 'Failure: Gsas Sync process could not complete the file transfer'
    FAILURE_BODY = "The Gsas Sync process failed to complete the transfer process.\nA log file has been attached "\
    "detailing what occurred.\nPlease address any validation errors and contact the DLST to attempt the transfer " \
    "again.\nThe files were not deleted on the remote transfer server."

    def initialize(log_file_name)
      @server = GsasSync::Config.mail_server['host']
      @port = GsasSync::Config.mail_server['port']
      @sender = GsasSync::Config.mail_server['sender_address']
      @recipients = GsasSync::Config.mail_server['recipients']
      @log_file = "#{GsasSync::Config.logs_directory}/#{log_file_name}"
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

    def log_file_str
      "#{FileUtils.pwd}/#{@log_file}"
    end

    def send_success_email(recipient, subject, body)
      attachment = log_file_str
      sender = @sender
      Mail.deliver do
        from sender
        to recipient
        subject subject
        body body
        add_file attachment
      end
    end

    def send_success_email_all
      GsasSync::Logger.stdout_logger.debug('GsasSync::EmailClient#send_success_email_all: Entry')
      subject = SUCCESS_SUBJECT
      body = SUCCESS_BODY
      @recipients.each { |email| send_success_email(email, subject, body) }
    end

    def send_failure_email_all
      subject = FAILURE_SUBJECT
      body = FAILURE_BODY
      @recipients.each { |email| send_failure_email(email, subject, body) }
    end

    def send_failure_email(recipient, subject, body)
      attachment = log_file_str
      sender = @sender # lexical scope needed for Mail.deliver block; use local variables
      Mail.deliver do
        from sender
        to recipient
        subject subject
        body body # body
        add_file attachment
      end

      # TODO: log success
    end
  end
end
