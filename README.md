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
### Ready your local dev environment
#### Using ssh tunnelling to the test transfer server:
While developing locally, we connect to the test transfer server as the special transfer user. You should obtain a copy of that user's private SSH key and put it in your dev machine's `~/.ssh` directory. Additionally, create a local `config/config.yml` and populate it with the proper credentials. Refer to spec/fixtures/config.yml for reference.

The test and production transfer servers will only allow connections from `connect.cul.columbia.edu`, so you should SSH tunnel to that server while developing locally. You can do so with [sshuttle](https://sshuttle.readthedocs.io/en/stable/) (on mac, you can [install sshhuttle with Homebrew](http://formulae.brew.sh/formula/sshuttle)). Then use the following command to forward your traffic to the connect server while developing:
```
sshuttle -r YOUR_UNI@connect.cul.columbia.edu 0.0.0.0/0
```

#### Using a VM as a test server:
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
