# pass.sh — A simple, posix shell compatible version of [password-store](https://www.passwordstore.org)

A local, gpg based, password manager.

Essential features work with only gnupg (to encrypt/decrypt) and busybox (for core shell utilities if they are not provided by other means (coreutils?)). Optional features only work if their requirements are installed (clipboard, fuzzy search, TOTP, 'correct horse' password generation).

This does not conform perfectly to the interface of the original pass.
This only has the features I use from `pass`, but I am willing to consider adding more if there is justified demand.

I edit password files in vim with the [vim-gnupg](https://github.com/jamessan/vim-gnupg) plugin to handle encrypted files. This turns off features like persistent undo which would otherwise be a security concern. A `pass edit` subcommand would need to have the necessary safeguards in place. (Maybe the user can specify that they trust their $EDITOR?)

Adding, removing, copying, and renaming files is done with standard unix commands, not this tool.

Creating password files needs to know the gpg key to use, password-store saved it in the `HOME/.password-store/` directory in `.gpg-id`. I never used this feature, I found it more convenient to have a `.template.gpg` file that gets copied and then edited (by whichever means the user uses), this can remember to encrypt to multiple keys.
I do not want such a tool creating new files if they don't exist. If we want `pass` to create new files I would place that behind a --create flag.

Storing TOTP credentials in a password manager is, maybe, not the best idea: it can turn 2FA into single factor. I used this for testing OTP solutions only... Do what you want with it.

The fzf and fzy subcommands skip any passwords in the `~/.password-store/.old` directory.

## Installation

```shell
install -p -m755 pass.sh /usr/local/bin
ln -s pass.sh /usr/local/bin/pass
```
You probably need `sudo` or `doas` to install. This is a program that handles your secrets, make sure you know you know what you are doing.

## Quickstart

```shell
mkdir -p "$HOME/.password-store"
echo 'template password' | gpg --encrypt --output "$HOME/.password-store/.template.gpg"

pass -c .template
```

## Requirements
- gnupg	of course (https://www.gnupg.org/)
- xclip	for copy to clipboard (https://github.com/astrand/xclip)
- otp		oathtool from oath-toolkit (https://oath-toolkit.codeberg.page)
- fzf		fzf (https://github.com/junegunn/fzf)
- fzy		fzy (https://github.com/jhawthorn/fzy)
- words   'xkcd' password generation needs a wordlist file at `/usr/share/dict/words`
- wl-clipboard    for copy to clipboard under wayland (https://github.com/bugaevc/wl-clipboard)


## TODO
- Turn todo into a Roadmap with checked features that we do want to work on and uncheched features that we have no interest in?
- [-] Add manpage?
### add cmds
- [ ] init?
- [ ] ls?
    - [ ] AKA list
    - uses `tree`
- [ ] grep
- [ ] find
    - [ ] AKA search
    - uses `tree`
- [ ] show
- [ ] insert
    - [ ] backup first? By option?
    - [ ] Insert a new first line leaving the old password as line 2.
- [ ] generate
    - [ ] Insert a new first line leaving the old password as line 2.
    - [ ] [xkcdpass](https://github.com/redacted/XKCD-password-generator)
        - `xkcdpass --case=as-is --delimiter='.'`
    - [ ] [pwgen](https://github.com/tytso/pwgen)
        - `pwgen --secure 64`
    - [ ] /dev/random
        - `LC_ALL=C tr -dc 'a-zA-Z0-9-_!@#%&+?=' < /dev/urandom | head -c $pwlen`
        - ``
    - [ ] `grep -v -E "'|^.{1,$((pw_word_len-1))}$" /usr/share/dict/words | shuf -n "$pw_word_count" | tr '\n' "$pw_word_separator" | sed 's/.$/\n/'`
        - depends: words package (or words-gb / words-en / words-*)
- [ ] edit
    - $EDITOR
    - vi
    - ? Do we trust this? Need to make sure file is handled in a secure manner.
- [-] rm
- [-] mv
- [-] cp
- [-] git
- [ ] qrcode
### add features
- [x] support xsel
- [x] support wl-clipboard

