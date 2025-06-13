# GsasSync

The GsasSync script manages the transfer of dissertations from GSAS to the library's collections.

In particular, it will run on a cron job once a month in order to syncronize and verify the transfer of GSAS dissertations. It retrieves the files from an [AWS Transfer Server](http://docs.aws.amazon.com/transfer/latest/userguide/what-is-aws-transfer-family.html) via [SFTP](https://en.wikipedia.org/wiki/SSH_File_Transfer_Protocol), verifies that the correct files have been downloaded successfully and in the expected format, and then removes them from the remote server. This Transfer Server is managed by GSAS, who will upload each month and maintain backup copies. An email will be sent to relevant parties when the process succeeds or fails (with a log file attached).

## Local development
### Install and run the script
```
git clone git@github.com:cul/gsas_sync.git
cd gsas_sync

bundle install    # Install dependencies
rbenv install     # Install correct ruby version

# Create an SSH Tunnel
sshuttle -r YOUR_UNI@connect.cul.columbia.edu 0.0.0.0/0

ruby gsas_sync_main.rb      # Run the script
```
### Command Line Interface
The gsas sync script supports two command line arguments for setting the standard out logging level and running the script in dry-run mode. Use the `-h` flag to see the usage script:
```
% ruby gsas_sync_main.rb --help
Usage:
	ruby gsas_sync_main.rb [options]
    -l, --log-level [LLVL]           Specify the runtime log level (debug, info, warn, error, fatal - default is 'debug')
        --dry-run [DRYRUN]           Run as dry-run
```
#### Dry-Run Mode
The gsas sync script supports a dry-run option to download and validate transfer directories without making any permanent changes to either the rmeote server or the local host.
```
ruby gsas_sync_main.rb --dry-run
```
In detail:
 - files will be downloaded to a `.temp` directory in the configurable storage location
 - downloaded `.temp` directories will be validated (see Validation Rules section) and then deleted
 - no files will be deleted from the remote transfer server
 - a progress log file will be created and saved under the configurable logs location
 - no email notifications will be sent
 - skipped operations (like removing the files from the remote transfer server, moving the `.temp` directory to a permanent one, sending email notifications, e.g.) will be logged
### Readying your local dev environment
#### Configuration file
The script expects a configuration file located in `<project_root>/config/config.yml`. It should have the following structure:
```
config:
  sftp_server:
    host: TRANSFER_SERVER_IP_OR_HOSTNAME
    user: TRANSFER_SERVER_USER
    key: PATH_TO_SSH_KEY
  mail_server:
    host: MAIL_SERVER_IP_OR_HOSTNAME
    port: PORT
    sender_address: "gsas-sync-no-reply@library.columbia.edu" (CAN BE ANY EMAIL YOU WOULD LIKE)
    recipients:
      - EMAIL_RECPIENT_ADDRESS
      - ...
  logs:
    directory: LOGS_DIRECTORY_NAME
  storage:
    directory: ABSOLUTE_PATH_TO_FINAL_STORAGE_DIRECTORY
```
#### Using ssh tunnelling to the test transfer server:
While developing locally, we connect to the test transfer server as the special transfer user. You should obtain a copy of that user's private SSH key and put it in your dev machine's `~/.ssh` directory. Additionally, create a local `config/config.yml` and populate it with the proper credentials. Refer to spec/fixtures/config.yml for reference.

The test and production transfer servers will only allow connections from `connect.cul.columbia.edu`, so you should SSH tunnel to that server while developing locally. You can do so with [sshuttle](https://sshuttle.readthedocs.io/en/stable/) (on mac, you can [install sshhuttle with Homebrew](http://formulae.brew.sh/formula/sshuttle)). Then use the following command to forward your traffic to the connect server while developing:
```
sshuttle -r YOUR_UNI@connect.cul.columbia.edu 0.0.0.0/0
```

#### Using a VM as a test server (Reccomended):
Alternatively, you can run your own server to use as the test transfer server. This is nice because you can put whatever you want in the server you spin up, without worrying about access rights or muddying the test transfer server that is maintained by LIT. Here is a brief guide to setting this up:
1. Install virtual machine software. On mac, we recommend [VMWare Fusion](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion) (this will require account creation in order to install). On windows, [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) would likely be a great option.
2. Download an ISO appropriate for our needs and spin up a VM. I use an [Ubuntu Live Server (for ARM)](https://ubuntu.com/download/server/arm) image. _Make sure to download the ARM architecture ISO if using a mac with Apple Silicon_. Boot and set up the new VM.
    - To find the IP address of your new machine, you can use the `ip a` command.
3. Create an [SSH-keypair](https://docs.oracle.com/en/cloud/cloud-at-customer/occ-get-started/generate-ssh-key-pair.html) on your parent machine. Add your public key to the `authorized_keys` file on the remote host.
    - Method 1 (recommended): Add your key to the remote with the `ssh-copy-id` utility.
        - `ssh-copy-id -i ~/.ssh/vm-id_ed25519.pub ROOT_USER@REMOTE_IP_ADDR` from your 'parent' machine.
    - Method 2: You can also use the [secure copy command](https://linux.die.net/man/1/scp) to copy the public key you created to the remote machine:
        - `scp ~/.ssh/your_ssh_key.pub ROOT_USER@IP_OF_VM:~/.ssh/your_ssh_key.pub` to copy the file to the remote host.
        - then add it to the `authorized_keys` file (Using any means you like. Example: in an SSH session: `ROOT_USR@REMOTE: ~/.ssh$ echo your_ssh_key.pub >> authorized_keys`).
4. Confirm that you can reach the VM without a password: 
    - `ssh ROOT_USER@REMOTE_IP_ADDR -i ~/.ssh/your_ssh_key`
5. On the remote host, create an `uploads/' directory in the home directory. `gsas_sync` expects this directory to exist and will download dissertations from there. Populate it with any data you'd like while developing. See "expected transfer server directory structure" for more information.
6. Add your VM host name, root user name, and private key location (on parent machine) to `config/config.yml`. These values will be used when `gsas_sync` makes connections to the transfer server.

### Validation Rules
```
1.   All required files present 
    1.1. The manifest file exists and has an accepted algorithm in it
    1.2. An yyyy_mm_items.csv file with a matching prefix exists
    1.3. An yyyy_mm_assets.csv file with a matching prefix exist
2.  No undesireable characters are present in any of the file/directory names
3.  All files listed in the manifest file are accounted for
    3.1.  All files listed in the manifest exist in the downloaded temp directory
    3.2.  All files in the downloaded temp directory (besides metadata files) are listed in the manifest
4.  The checksums listed for each file in the manifest match the checksums for what was downloaded
```

### Expected transfer server directory structure
```
uploads/
├─ 2025_04_dissertations/
│  ├─ data
│  ├─ data
|     ├─ bowie_david
|        ├─ who_is_ziggy_stardust.pdf
|        ├─ ziggy_stardust.pptx
|        ├─ ziggy_stardust_explained.mp4
|     ├─ haines_emily
|        ├─ haines_dissertation.pdf
|     ├─ daltrey_roger
|        ├─ daltrey_dissertation.pdf
│  ├─ manifest-sha256.txt
│  ├─ 2025_04_items.csv
│  ├─ 2025_04_assets.csv
├─ 2025_05_dissertations/
│  ├─ data
│  ├─ manifest-sha256.txt
│  ├─ 2025_05_items.csv
│  ├─ 2025_05_assets.csv
```
### Testing
```
bundle exec rspec spec
```
