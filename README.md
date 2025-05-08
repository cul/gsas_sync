# GsasSync

The GsasSync script manages the transfer of dissertations from GSAS to the library's collections.

In particular, it will run on a cron job once a month in order to syncronize and verify the transfer of GSAS dissertations. It retrieves the files from an [AWS Transfer Server](http://docs.aws.amazon.com/transfer/latest/userguide/what-is-aws-transfer-family.html) via [SFTP](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol), verifies that the correct files have been downloaded successfully and in the expected format, and then removes them from the remote server. This Transfer Server is managed by GSAS, who will upload each month and maintain backup copies.

## Local development
#### Install and run the script
```
git clone UPDATE_WITH_CUL_REPO
cd gsas_sync

bundle install    # Install dependencies
rbenv install     # Install correct ruby version

# Create an SSH Tunnel
sshuttle -r bg2918@connect.cul.columbia.edu 0.0.0.0/0

ruby main.rb      # Run the script
```
#### Ready your local environment
While developing locally, we connect to the test transfer server as the special transfer user. You should obtain a copy of that user's private SSH key and put it in your dev machine's `~/.ssh` directory. Additionally, create a local `config/config.yml` and populate it with the proper credentials. Refer to spec/fixtures/config.yml for reference.

The test and production transfer servers will only allow connections from `connect.cul.columbia.edu`, so you should SSH tunnel to that server while developing locally. You can do so with [sshuttle](https://sshuttle.readthedocs.io/en/stable/) (on mac, you can [install sshhuttle with Homebrew](http://formulae.brew.sh/formula/sshuttle)). Then use the following command to forward your traffic to the connect server while developing:
```
sshuttle -r YOUR_UNI@connect.cul.columbia.edu 0.0.0.0/0
```

### Testing
```
bundle exec rspec spec
```