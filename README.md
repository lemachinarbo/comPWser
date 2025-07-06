# comPWser

A lazy-simple way to install ProcessWire, plus one-command setup for GitHub deploy workflows to staging, prod, testing — you named it.
Based on [RockMigrations deployments](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#update-config.php) and following [processwire.dev structure](https://github.com/MoritzLost/ProcessWireDev/blob/master/site/02-setup-and-structure/02-integrate-composer-with-processwire.md).

With ComPWser you can do 2 things:
1. [Quick Install Processwire](#21-quick-install-processwire)
2. Set up [automated GitHub Actions](#22-quick-deployment-setup-with-github-actions) to deploy your site to production (or staging, testing, etc.) with minimal effort.
3. Nop, only two.


## 1. Requirements

- DDEV
- Composer (Included by default with DDEV)
- PHP >= 8.0  

## 2. Installation

### 2.1 Quick Install Processwire

Set the `docroot` of your DDEV container to `public` by updating `docroot: public` in `./.ddev/config.yaml`, then download the Composer project file and run the install.

```sh
ddev config --docroot=public
ddev restart
wget https://raw.githubusercontent.com/lemachinarbo/comPWser/main/composer.json
ddev composer install
```

#### What It Does
- Downloads [ProcessWire](https://github.com/processwire/processwire/)
- Adds [RockMigrations](https://github.com/baumrock/RockMigrations) and [RockShell](https://github.com/baumrock/RockShell) as Git submodules
- Installs ProcessWire in `/public`
- Installs the RockMigrations module
- Backups Database
- Cleans up leftover core files
- Downloads build files (`./build`) in case you want to set up GitHub Workflows for deployment
- Adds a `.gitignore` file for your repository

Happiness.

### 2.2 Quick Deployment Setup with GitHub Actions

> Note: For a step by step explanation check [the step-by-step guide](./.build/docs/guide.md)

1. Create a [new GitHub repository](https://github.com/new) for your project.
2. Create a [Personal Access Token](https://github.com/settings/personal-access-tokens) with access to the repository you created and Read/Write access for actions, contents, deployments, secrets, variables, and workflows.
3. Create an environment file using the `.env template` and complete all the information:

```sh
mv ./.build/templates/.env.example ./.env
```

4. Create the `SSH keys` and upload them to your remote server:

```sh
chmod +x ./.build/scripts/sshkeys-generate.sh && ./.build/scripts/sshkeys-generate.sh
```

5. Install [GitHub CLI](https://github.com/cli/cli#installation) and, once installed, authenticate by running:

```sh
gh auth login
```

Select `id_github.pub` as your public SSH key when prompted.

6. Run the installer and follow the steps to create an environment. The name is up to you — `production`, `staging`, `stage`, `prod`, `dev`, `test`, whatever.

```sh
chmod +x ./.build/setup.sh && ./.build/setup.sh
```

If you need multiple environments (e.g., production, staging, testing), update the `.env` accordingly and run `./.build/setup.sh` once per environment.


#### What It Does
- Checks for all requirements: `.env` file, SSH keys, GitHub CLI, and repository access
- Offers to generate missing SSH keys and register them with your server
- Sets up GitHub Actions variables and secrets for your chosen environment
- Lets you select which branch to link to your deployment environment and generates workflow files
- Creates or updates `config-local.php` from your `.env` file for environment-specific
- Syncs all project files—including ProcessWire, RockShell, and modules—to your remote server
- Imports your local database to the server for the selected environment
- Updates the server folder structure and permissions for automated deployments
- Prompts you at each step so you can skip or rerun any part of the setup


What's next? Check what else you can do when [moving to production](https://www.baumrock.com/en/processwire/modules/rockmigrations/docs/deploy/#rockshell-filesondemand).

Nice. Time to enjoy some cake.

## 3. F.A.Q

### 3.1 Why are you downloading ProcessWire with composer?

Because I would love to use the *GitHub Workflows deployment* thing without committing the `wire` folder to my repository and I hope/suspect composer will be the way.

### 3.2 Why do you say `with one command` if installation requires more than one?

It’s more catchy… and honestly, my original intention was just one command, but turns out I needed more. Classic rookie “I-can-do-everything-because-I-learned-to-type-into-the-AI-chat-box” miscalculation.

### 3.3 Can I personalize the ProcessWire installation rather than accept your opinionated defaults?

To install ProcessWire, I am using [PWInstaller](https://github.com/lemachinarbo/RockShell/blob/8ddcea56fe1cd7c678ba18df81b1834a6b1fd27f/App/Commands/PwInstaller.php), a variation of [Bernhard's installer](https://github.com/baumrock/RockShell/blob/21d6808c35fbbcbf192f05b3fd3d88fa96b2b7cf/App/Commands/PwInstall.php) that allows you to skip the prompts and install ProcessWire using some default settings. If you want an interactive ProcessWire installation, simply remove the `--lazy` parameter in the `composer.json` file

```
[ -f RockShell/rock ] && php RockShell/rock pw:installer --lazy || echo 'RockShell command not available'
```

like this:

```
[ -f RockShell/rock ] && php RockShell/rock pw:installer || echo 'RockShell command not available'
```

If you want to keep your custom settings Installer, update `$lazyDefaults` on PWInstaller command.

```php
private $lazyDefaults = [
// Host/General
// 'host' => 'foo.ddev.site', // host is autodetected but can be overridden
'debug' => false,
'download_processwire' => true,
'processwire_version' => 'dev',
'download_rockfrontend' => false,
'profile' => 'site-blank', // site-rockfrontend requires download_rockfrontend to be true
// Database
'dbName' => 'db',
'dbUser' => 'db',
'dbPass' => 'db',
'dbHost' => 'db',
'dbCon'  => 'Hostname',
'dbPort' => 3306,
'dbCharset' => 'utf8mb4',
'dbEngine' => 'InnoDB',
'dbTablesAction' => 'remove', // remove existing tables if pw is already installed
// Admin
'admin_name' => 'processwire',
'username' => 'ddevadmin',
'userpass' => 'ddevadmin',
'userpass_confirm' => 'ddevadmin',
'useremail' => 'admin@example.com',
// Site
'timezone' => 'America/Bogota', // find yours at https://www.php.net/manual/en/timezones.php
'debugMode' => 1,
];
```

### 3.4 What's with the cake?  

The cake is a lie.