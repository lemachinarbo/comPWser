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

**Note:** Only tested locally in a DDEV environment.

