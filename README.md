# Chips

Useful tiny scripts, which aren't big enough to be single standalone projects.

## Usage

You can directly use the chips by running them.

I strongly suggest you to setup them into your system, making them convenient to use.

Run the setup script:

```shellsession
$ ./setup
```

*The setup script will prompt you some questions to choose and tune the chips to suit your needs.*

## Structure

Chips are divided by category:

* [`app-wrapper`](./scripts/app-wrapper) (`WIP`): Application wrappers
* [`backup`](./scripts/backup): Chips for backups
* [`fzf`](./scripts/fzf): Chips specific for `fzf`
* [`gafs`](./scripts/gafs) (`WIP`): Chip "Gimme-a-f\*cking-shell"
* [`gentoo`](./scripts/gentoo): Chips specific for `Gentoo`-based systems
* [`git`](./scripts/git): Chips related to `git` VCS
* [`jee`](./scripts/jee): Chips for `Java Enterprise Edition`
* [`linux`](./scripts/linux): Chips for all types of `GNU/Linux`es (no distro-specific)
* [`openssl`](./scripts/openssl): Chips related to `openssl`
* [`osx`](./scripts/osx): Chips specific for `OSX`

## Development

Setup:

```
$ bundle install
```

### Ruby chips

Chips written in Ruby rely on framework `sfw` (automatically embedded into the chip), so you should use Ruby as much as possible.
