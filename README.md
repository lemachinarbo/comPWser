# comPWser

A lazy-simple way to install and bootstrap ProcessWire with one command.
Based on [processwire.dev](https://github.com/MoritzLost/ProcessWireDev/blob/master/site/02-setup-and-structure/02-integrate-composer-with-processwire.md) and [RockShell](https://github.com/baumrock/RockShell/).

## What It Does

- Downloads [ProcessWire](https://github.com/processwire/processwire/), [RockMigrations](https://github.com/baumrock/RockMigrations), and [RockShell](https://github.com/baumrock/RockShell)
- Installs ProcessWire in `/public` (via RockShell)
- Installs the RockMigrations module
- Cleans up leftover files from the core

## Requirements

- PHP >= 8.0  
- Composer

## Install

```bash
wget https://raw.githubusercontent.com/lemachinarbo/comPWser/main/composer.json
composer install
```

That's it.

## Regarding ProcessWire Installation

To install ProcessWire, I am using [PWInstaller](https://github.com/lemachinarbo/RockShell/blob/8ddcea56fe1cd7c678ba18df81b1834a6b1fd27f/App/Commands/PwInstaller.php), a variation of [Bernhard's installer](https://github.com/baumrock/RockShell/blob/21d6808c35fbbcbf192f05b3fd3d88fa96b2b7cf/App/Commands/PwInstall.php) that allows you to skip the prompts and install ProcessWire using the default settings. If you want an interactive ProcessWire installation, simply remove the `--lazy` parameter in the `composer.json` file

```
[ -f RockShell/rock ] && php RockShell/rock pw:installer --lazy || echo 'RockShell command not available'
```

like this:

```
[ -f RockShell/rock ] && php RockShell/rock pw:installer || echo 'RockShell command not available'
```

## Step by step guide

This guide assumes you're using DDEV for local development. Aren’t you? If not, it's time to (convert)[https://ddev.com/get-started/].

That said, you don’t need DDEV to follow along — just adapt any DDEV-specific references as needed.

## Part 1: Local processwire installation

### Project structure

When installing ProcessWire, I like to follow the structure from (MoritzLost's Composer Integration guide)[https://processwire.dev/integrate-composer-with-processwire/#recommended-directory-structure-for-processwire-projects-with-composer]. Why? because it keeps all ProcessWire files in one folder and leaves everything else—packages, build tools, vendor, node stuff—outside. So, this is the setup we'll be going with:

```
/                  # root
├── composer.json  # Composer config
├── public         # webroot (contains ProcessWire)
│   ├── index.php
│   ├── site       
│   ├── wire       
│   └── ...
└── vendor         # Composer dependencies
└── node_modules   # Other dependencies...
```

This means we have to define the `public` folder as our `webroot` in our local environment. 
In DDEV we can do this at the start of the project by running `ddev config` 

```sh
Docroot Location (project root): public
```

Or, if we already have a project, by editing the `docroot` line in the `.ddev/config.yaml` file:

```yaml
name: oz
type: php
docroot: public  # <--- This one
php_version: "8.4"
webserver_type: apache-fpm
xdebug_enabled: false
additional_hostnames: []
additional_fqdns: []
database:
    type: mariadb
    version: "10.11"
use_dns_when_possible: true
composer_version: "2"
web_environment: []
corepack_enable: false
```

### Installing Processwire

Good news, installing is the easy part. We just need to download the Composer "installer" into our project `root` directory and run `composer install`:

```bash
wget https://raw.githubusercontent.com/lemachinarbo/comPWser/dev/composer.json
ddev composer install
```

> `ddev composer` allows you to execute composer commands in your web container. Alternatively, you can enter the web container using `ddev ssh` and then run `composer install` 

And that's it! You can test your Processwire installation: https://yourwebsite.ddev.site/

## Part 2: Automating deployments

comPWser is essentially a collection of scripts to automate the setup of a ProcessWire project, following the (Deployments guide)[https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php] from @baumrock.

If you have never heard of or used Deployments before, please start by reading his guide ((a step by step video)[https://www.youtube.com/watch?v=4wS7xWUtFes] is included!). 

> **Note:** A GitHub repository for the project is required, [create one](https://github.com/new) if you haven't already.


### 1. Creating a .env environment file

Inside the `.build` folder you will find a `.env.example` template. Please copy to your root and rename to `.env`:

```sh
mv ./.build/.env.example ./.env
```

Open the file and edit the values, here's an example:

```sh
# GitHub repository details
GITHUB_OWNER=lemachinarbo
GITHUB_REPO=test
CI_TOKEN=  # Leave this for the next step

# SSH details — used to connect to the hosting server
SSH_HOST=myserver.com
SSH_USER=myusername
SSH_KEY=id_github # We will be creating this key later

# Deployment details

# Path to your "webroot", the website's public directory on the server 
DEPLOY_PATH=/var/www/html

# If ProcessWire is installed in the public folder: PW_ROOT=public
# If installed in the root folder, set it empty: PW_ROOT=
PW_ROOT=public

# Add your server configuration details below
SERVER_HOST=yourdomain.com
SERVER_DB_HOST=localhost
SERVER_DB_USER=example_user
SERVER_DB_NAME=example_db
SERVER_DB_PASS=password1234
```

#### Creating a Github Personal Access Token

Go to Github's (personal access tokens)[https://github.com/settings/personal-access-tokens]  `profile > developer settings > personal acces tokens  > fine-grained tokens` and click the `generate new token` button.

Choose a name for the token, set the expiration to at least 90 days and in repository access select `Only selected repositories` and choose your project repository.

For the repository permissions select Read Write access for actions, contents, deployments, secrets, variables and workflows, and click on `Generate token`.

Copy the token and paste it in your .env file

```sh
CI_TOKEN=github_pat_xxx
```


#### 2. Creating SSH keys

To connect with our remote server and Github we will be using a pair of SSH keys (one personal key named `id_ed25519` and another one that we can reuse in our projects `id_github`). 

Run this script to create and test the keys:

```sh
chmod +x ./.build/ssh_keys.sh && ./.build/ssh_keys.sh
```

You will get a confirmation message like this:
```
Testing personal key authentication...
✓ Personal key authentication successful.
Testing project key authentication...
✓ Project key authentication successful.

All SSH key operations complete.
Personal and project keys were created (if missing), uploaded to the server, and authentication was tested successfully.
```

#### 3. Installing Github CLI

Github CLI allow us to manage several Github features from the terminal, allowing our scripts to automate repository setup creating all required variables and secrets for you.

Start by installing (Github CLI)[https://github.com/cli/cli#installation]. Once installed authenticate by running:

```sh
gh auth login
```

Follow the prompts and be sure to select the `id_github.pub` SSH key when asked to *upload your public key to your GitHub account*.


#### 4. Running bootstrap

No more setup is needed. Run the bootsrap script and follow the prompts:

```sh
chmod +x ./.build/bootstrap.sh && ./.build/bootstrap.sh
```

And we are done! Check your server webroot folder and you will have something like this:

```
/path/to/your/webroot/
├── current     # Symlink to the current release (e.g. release-1)
├── release-1   # Current release directory
├── shared/     # Shared files (e.g. user uploads, logs, cache)
```

Update your web server configuration (e.g., Apache, Nginx, or your hosting control panel) to point the document root to the current symlink instead of the base webroot directory. This way, your website will always serve the latest deployed release.

Update your server setting to define current as your new webroot and your website will be visible!

```
OLD: /path/to/your/webroot
NEW: /path/to/your/webroot/current
```
