# Step by step guide

This guide assumes you're using DDEV for local development. Aren’t you? If not, it's time to [convert](https://ddev.com/get-started/).

## 1. Part 1: Local processwire installation

### 1.1. Project structure

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

### 1.2. Installing Processwire

This is the easy part! We just need to download the Composer "installer" into our project `root` directory and run `composer install`:

```bash
wget https://raw.githubusercontent.com/lemachinarbo/comPWser/dev/composer.json
ddev composer install
```

> `ddev composer` allows you to execute composer commands in your web container. Alternatively, you can enter the web container using `ddev ssh` and then run `composer install` 

And that's it! You can test your Processwire installation: https://yourwebsite.ddev.site/

## 2. Part 2: Automating deployments

comPWser is essentially a collection of scripts to automate the setup of a ProcessWire project, following the (Deployments guide)[https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php] from [@baumrock](https://github.com/baumrock/).

The goal: make the whole GitHub Actions setup way quicker and less annoying — no more clicking around to create secrets, variables, environments, workflows, etc.

> **Note:** If you've never heard of or used Deployments before, start by reading Bernhard's guide (there’s a [step-by-step video](https://www.youtube.com/watch?v=4wS7xWUtFes) included!).

But let me pause for a sec and explain why we even bother with these deployment workflows.

The goal is simple: make it easy to move the site you’re working on locally to a live or staging server — without headaches. No more surprises because some config values in your server setup are different, or realizing too late you forgot to sync the DB, or worse... you just overwrote the client’s latest changes. All that messy, manual chaos we’ve all been through (maybe not you, but yeah... I’m guilty).

That’s where an automated deployment workflow comes in. In our case, it means:

You push to a branch → stuff magically gets deployed to a matching environment.
And you can have as many as you want:

* `main` branch → `website.com`
* `develop` branch → `staging.foo.com`
* `testing` branch → `testing.bar.com`
* `coolfeature` branch → `feats.bar.com`
* And so on...

So, now that you get the picture, let's get this party started:

### 2.1. Preparing the requirements

#### 2.1.1. Github Repository

A GitHub repository is required for the project. Start by [creating one](https://github.com/new) if you haven't already.

#### 2.1.2. Creating a .env environment file

Inside the `[.build](./../../.build/)` folder, you will find the `[.env.example](../templates/.env.example)` template. Copy it to your project root and rename it to `.env`:

```sh
mv ./.build/.env.example ./.env
```

Then open the file and edit the values. Let me walk you through it with an example.
First part’s simple —just provide your GitHub username and the project’s repo name:

```sh
GITHUB_OWNER=lemachinarbo
GITHUB_REPO=myrepo
CI_TOKEN=  # Leave this value empty; we will populate it in the next step.

# An SSH key named id_github will be created later, so you can leave SSH_KEY as is.
SSH_KEY=id_github 

# comPWser installs ProcessWire in the 'public' subdirectory, leave it as is.
PW_ROOT=public
```

Next, we define the environments. This is the base for generating the GitHub Actions workflows —so it's kinda important. You need to declare every environment you want here.

If you’re only deploying to production, just do:

```sh
ENVIRONMENTS="PROD"
```

But if you want more, list them all:
```sh
ENVIRONMENTS="PROD STAGING TESTING COOLFEATURES"
```

Then provide the info for each environment **using its name as a prefix**:

```sh
ENVIRONMENTS="PROD STAGING"

PROD_SSH_HOST=website.com
PROD_SSH_USER=myserveruser
PROD_HOST=website.com
PROD_DB_HOST=localhost
PROD_DB_USER=website_db
PROD_DB_NAME=db_user
PROD_DB_PASS=password1234
# PROD_DB_PORT=3306
# PROD_DB_CHARSET=utf8mb4
# PROD_DB_ENGINE=InnoDB
PROD_PATH=/var/www/html
PROD_HTACCESS_OPTION=SymLinksifOwnerMatch
PROD_DEBUG=FALSE

# And the same for STAGING

STAGING_SSH_HOST=website.com
STAGING_SSH_USER=myserveruser
STAGING_HOST=website.com
STAGING_DB_HOST=localhost
STAGING_DB_USER=website_db
STAGING_DB_NAME=db_user
STAGING_DB_PASS=password1234
# STAGING_DB_PORT=3306
# STAGING_DB_CHARSET=utf8mb4
# STAGING_DB_ENGINE=InnoDB
STAGING_PATH=/var/www/html
STAGING_HTACCESS_OPTION=SymLinksifOwnerMatch
STAGING_DEBUG=FALSE
```

Remember, you can name your environments however you like. We’re just using `PROD` and `STAGING` because we’re boring and predictable.


#### 2.1.3. Creating a Github Personal Access Token

Go to Github's (personal access tokens)[https://github.com/settings/personal-access-tokens]  `profile > developer settings > personal acces tokens  > fine-grained tokens` and click the `generate new token` button.

Choose a name for the token, set the expiration to at least 90 days and in repository access select `Only selected repositories` and choose your project repository.

For the repository permissions select Read Write access for `actions`, `contents`, `deployments`, `secrets`, `variables` and `workflows`, and click on `Generate token`.

Copy the token and paste it in your .env file

```sh
CI_TOKEN=github_pat_xxx <--- HERE!
```

#### 2.1.4. Creating the SSH keys

Now it’s time to generate a pair of SSH keys —super handy for passwordless access to your environments.

Run this script. It’ll create two keys:

* A personal one: `id_ed25519`
* A reusable project one: `id_github`

```sh
chmod +x ./.build/scripts/sshkeys-generate.sh && ./.build/scripts/sshkeys-generate.sh
```

If you see something like this, you’re set:

```
Testing personal key authentication...
✓ Personal key authentication successful.
Testing project key authentication...
✓ Project key authentication successful.
```

If not... well, you're not set 😅
Check the error and try again.


#### 2.1.5. Installing Github CLI

GitHub CLI lets us manage a bunch of GitHub stuff right from the terminal — which means our scripts can automate the whole repo setup: creating all the required variables, secrets, environments, etc.
(and also, probably means that the scripts are just a wrapper and it’s the GitHub CLI the one doing all the heavy lifting.)

Start by installing (Github CLI)[https://github.com/cli/cli#installation]. Once installed authenticate by running:

```sh
gh auth login
```

Follow the prompts and be sure to select the `id_github.pub` SSH key when asked to *upload your public key to your GitHub account*.

### 2.2. Setuping the workflows

All that’s left is to run the setup script and follow the instructions. Don’t skip anything and enjoy the ride:

```sh
chmod +x ./.build/setup.sh && ./.build/setup.sh
```

Once it’s done, check your server’s docroot folder —you should see something like this:

```
/path/to/your/docroot/
├── current     # Symlink to the current release (e.g. release-1)
├── release-1   # Current release directory
├── shared/     # Shared files (e.g. user uploads, logs, cache)
```

This means, that in order to make tour website visible you need to update the web server configuration (from your hosting control panel) to point the `docroot` to `current` instead of the base docroot directory. This way, your website will be always serving the latest deployed release (the last thing you pushed to your branch). 

After that visit yourdomain.com and enjoy a piece of [the cake](../../README.md#44-whats-with-the-cake)!

And to wrap it up: here’s a quick peek at what the installer will walk you through — just for reference.

```markdown
Welcome to the ComPWser Environment Setup tool
This script will guide you through setting up your environment for automated deployments.
----------------------------------------
Checking for requirements:
✓ .env file found at /home/lemachibarno/projects/ranma/.build/scripts/../../.env.
✓ Personal SSH key (id_ed25519) found.
✓ Project SSH key (id_github) found.
✓ GitHub CLI (gh) is installed.
✓ Repository username/repo found and accessible.

All requirements met. Let's start environment setup.

Which environment do you want to setup?
    1) PROD
    2) STAGING
Environment number [1]: 2

**Registering SSH Keys**
Allows automated deployments with passwordless SSH access.
----------------------------------------
Add keys now? [Y/n]:


**GitHub Actions Setup**
Automated deployment requires secrets and variables set in the GitHub PROD environment
----------------------------------------
Run GitHub Actions setup? [Y/n]: 


**GitHub Workflows Setup**
To trigger automated deployments, link a branch to the PROD environment in GitHub.
----------------------------------------
Select branch now? [Y/n]: 


**Config File Setup**
To separate local and production settings, your config.php will be split, creating a config-local.php for environment-specific overrides.
----------------------------------------
Create config-local.php? [Y/n]: 


**File Sync**
To deploy your site, all project files need to be uploaded and synced to the PROD server.
----------------------------------------
Sync files and deploy to server? [Y/n]: n


**Database Import**
Import local database to PROD server to run the site.
----------------------------------------
Import now? [Y/n]: 


**Environment Folder Structure**
A new folder structure is required on the PROD server for multi-version deployments.
----------------------------------------
Update folder structure? [Y/n]:


All selected steps completed!
Reminder: Commit and push your changes to the repository to test the deployment workflows.
```