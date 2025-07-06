# Step by step guide

This guide assumes you're using DDEV for local development. Aren’t you? If not, it's time to [convert](https://ddev.com/get-started/).

## Part 1: Local processwire installation

### Project structure

When installing ProcessWire, I like to follow the structure from [MoritzLost's Composer Integration guide]([https://processwire.dev/integrate-composer-with-processwire/#recommended-directory-structure-for-processwire-projects-with-composer). Why? because it keeps all ProcessWire files in one folder and leaves everything else—packages, build tools, vendor, node stuff—outside: 

```
/                  # root
├── composer.json  # Composer config
├── public         # docroot (contains ProcessWire)
│   ├── index.php
│   ├── site       
│   ├── wire       
│   └── ...
└── vendor         # Composer dependencies
└── node_modules   # Other dependencies...
```

To follow this structure we must define `public` as our `docroot` in our local environment. 

With DDEV, we can set this up right from the start when creating our project. Simply run `ddev config` and enter `public` as the `docroot` when prompted:

```sh
Docroot Location (project root): public
```

Or, if you already have a project, you can update the `docroot` by editing the `docroot` line in `.ddev/config.yaml` file:

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

Or, rigth from your terminal:

```sh
ddev config --docroot=public
ddev restart
```

### Installing Processwire

This is the easy part! We just need to download the Composer "installer" into our project `root` directory and run `composer install`:

```bash
wget https://raw.githubusercontent.com/lemachinarbo/comPWser/dev/composer.json
ddev composer install
```

> `ddev composer` allows you to execute composer commands in your web container. Alternatively, you can enter the web container using `ddev ssh` and then run `composer install` 

And that's it! You can test your Processwire installation: https://yourwebsite.ddev.site/

## Part 2: Automating deployments

comPWser is essentially a collection of scripts to automate the setup of a ProcessWire project, following the (Deployments guide)[https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php] from @baumrock.

If you have never heard of or used Deployments before, please start by reading Bernhard's guide ((a step by step video)[https://www.youtube.com/watch?v=4wS7xWUtFes] is included!). 

### 0. Github Repository

A GitHub repository for the project is required, [create one](https://github.com/new) if you haven't already.


### 1. Creating a .env environment file

Inside the `.build` folder, you will find a `.env.example` template. Copy it to your project root and rename it to `.env`:

```sh
mv ./.build/.env.example ./.env
```

The open the file and edit the values. Here's an example:

```sh
GITHUB_OWNER=lemachinarbo
GITHUB_REPO=myrepo
CI_TOKEN=  # Leave this for the next step

SSH_HOST=myserver.com
SSH_USER=myusername
SSH_KEY=id_github # We will be creating this key later

DEPLOY_PATH=/var/www/html
PW_ROOT=public # We installed ProcessWire here, leave as is

SERVER_HOST=yourdomain.com
SERVER_DB_HOST=localhost
SERVER_DB_USER=example_user
SERVER_DB_NAME=example_db
SERVER_DB_PASS=password1234

HTACCESS_OPTION=SymLinksifOwnerMatch # This one is explained in your .env.example file
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

Now let's generate a pair of SSH keys: a personal key named `id_ed25519`, and a reusable project key named `id_github` for connecting to your server. 

Run this script to create and test the keys:

```sh
chmod +x ./.build/sshkeys.sh && ./.build/sshkeys.sh
```

If you see a confirmation message like this one, you're all set:
```
Testing personal key authentication...
✓ Personal key authentication successful.
Testing project key authentication...
✓ Project key authentication successful.
```

#### 3. Installing Github CLI

Github CLI allow us to manage several Github features from the terminal, allowing our scripts to automate repository setup creating all required variables and secrets for you.

Start by installing (Github CLI)[https://github.com/cli/cli#installation]. Once installed authenticate by running:

```sh
gh auth login
```

Follow the prompts and be sure to select the `id_github.pub` SSH key when asked to *upload your public key to your GitHub account*.


#### 4. Running bootstrap

No more setup is needed! Run the bootsrap script and follow the prompts:

```sh
chmod +x ./.build/bootstrap.sh && ./.build/bootstrap.sh
```

And we are done! Check your server docroot folder and you will have something like this:

```
/path/to/your/docroot/
├── current     # Symlink to the current release (e.g. release-1)
├── release-1   # Current release directory
├── shared/     # Shared files (e.g. user uploads, logs, cache)
```

Which means, you need to update your web server configuration (from your hosting control panel) to point the `docroot` to `current` instead of the base docroot directory. This way, your website will be visible with the latest deployed release. 

```
OLD: /path/to/your/docroot
NEW: /path/to/your/docroot/current
```

Now go to yourdomain.com and test your website!