#!/bin/sh

while [ $# -gt 0 ] ; do
  case "$1" in
    otp)
      otp=1
      shift
      ;;
    fzf)
      fzf=1
      shift
      ;;
    fzy)
      fzy=1
      shift
      ;;
    -c|--clip|-clip)
      clip=1
      shift
      ;;
    -r|--norestore|-norestore)
      norestore=1
      shift
      ;;
    -q|--quiet|-quiet)
      quiet=1
      shift
      ;;
    -h|--help|-help|-V|--version|-version)
      echo 'pass v0.1'
      echo 'a local, gpg based, password manager'
      echo '  a simple, posix compliant, version of password-store.'
      echo '  released into the public domain.'
      echo "$0 [options] [command] item"
      echo 'Example: pass email'
      echo 'Example: pass otp website'
      echo 'Example: pass fzf'
      echo 'Options:'
      echo '  -c, --clip	copy first line of file to clipboard'
      echo '  -r, --norestore	do not wipe/restore the clipboard afterwards'
      echo '  -h, --help	show this help message (also -v, --version)'
      echo '  -q, --quiet	show fewer messages'
      echo 'Commands:'
      echo '  otp		produce totp code from otpauth:// line in file'
      echo '  fzf		select item using fzf fuzzy find'
      echo '  fzy		select item using fzy fuzzy find'
      echo 'Requirements:'
      echo '  gnupg		of course https://www.gnupg.org/'
      echo '  optionally one of:'
      echo '    xclip		for copy to clipboard https://github.com/astrand/xclip'
      echo '    xsel		for copy to clipboard https://vergenet.net/~conrad/software/xsel/'
      echo '    wl-clipboard	for copy to clipboard https://github.com/bugaevc/wl-clipboard'
      echo '  optionally, if you want the feature:'
      echo '    otp		oathtool from oath-toolkit https://oath-toolkit.codeberg.page'
      echo '    fzf		fzf https://github.com/junegunn/fzf'
      echo '    fzy		fzy https://github.com/jhawthorn/fzy'
      exit 0
      ;;
    *)
      original_name=$1
      shift
      [ $# -gt 1 ] && echo "Error: $0: Unknown arguments: '$*'." >&2
      break
      ;;
  esac
done

passfile="$original_name"
password_store="$HOME/.password-store"


if [ -n "$fzf" ] && [ -t 0 ] && [ -x "$(command -v fzf)" ]  ; then
  export FZF_DEFAULT_OPTS='--delimiter / --with-nth {5..} --walker-skip=.old'
  real_passfile=$(realpath "$password_store/${passfile}" 2>/dev/null)
  if [ -d "$real_passfile" ] ; then
    passfile="$(fzf --walker-root="$real_passfile")"
  else
    passfile="$(fzf --walker-root="$password_store" --query="$passfile")"
  fi
  ferr=$?
  [ $ferr -gt 0 ] && exit $ferr

  if [ ! -f "$passfile" ] ; then
    passfile="$original_name"
  fi
fi


if [ -n "$fzy" ] && [ -t 0 ] && [ -x "$(command -v fzy)" ]  ; then
  real_passfile=$(realpath "$password_store/${passfile}" 2>/dev/null)
  if [ -d "$real_passfile" ] ; then
    passfile="$password_store/$(find "$password_store" -name '.old' -prune -o -type f -path "$real_passfile/*.gpg" -printf '%P\n' | fzy)"
  else
    passfile="$password_store/$(find "$password_store" -name '.old' -prune -o -type f -iname '*.gpg' -printf '%P\n' | fzy --query="$passfile")"
  fi
  ferr=$?
  [ $ferr -gt 0 ] && exit $ferr

  if [ ! -f "$passfile" ] ; then
    passfile="$original_name"
  fi
fi


if [ "${passfile##*.}" != 'gpg' ] ; then
  passfile="${passfile}.gpg"
fi

real_passfile=$(realpath "${passfile}" 2>/dev/null)
if [ ! -f "$real_passfile" ] ; then
  real_passfile=$(realpath "$password_store/${passfile}" 2>/dev/null)
  if [ ! -f "$real_passfile" ] ; then
    echo "Error: '$original_name' not found in password-store." >&2
    exit 1
  fi
fi


output="$(gpg --quiet --decrypt "$real_passfile")"

if [ -n "$otp" ] ; then
  if [ ! -x "$(command -v oathtool)" ] ; then
    echo "Error: $0: oathtool not found can not produce OTP." >&2
    exit 2
  fi

  otpauth="$(echo "$output" | sed -n -r '/^otpauth/p')"
  if [ -z "$otpauth" ] ; then
    echo "Error: $0: otpauth not found in $original_name" >&2
    exit 3
  fi

  secret="$(echo "$otpauth" | sed -n -r 's/^.+secret=([^&]+).*$/\1/p')"
  if [ -z "$secret" ] ; then
    echo "Error: $0: otp secret not found in otpauth" >&2
    exit 4
  fi

  period="$(echo "$otpauth" | sed -n -r 's/^.+period=([^&]+).*$/\1/p')"
  digits="$(echo "$otpauth" | sed -n -r 's/^.+digits=([^&]+).*$/\1/p')"
  algorithm="$(echo "$otpauth" | sed -n -r 's/^.+algorithm=([^&]+).*$/\1/p')"

  output="$(
    echo "$secret" | oathtool --base32 \
      --totp="${algorithm:-SHA1}" \
      --time-step-size="${period:-30}" \
      --digits="${digits:-6}" \
      -
    )"
fi

if [ -n "$clip" ] ; then
  case "$XDG_SESSION_TYPE" in
    x11)
      if [ -x "$(command -v xclip2)" ] ; then
        clip_out='xclip -out'
        clip_in='xclip -in'
      elif [ -x "$(command -v xsel)" ] ; then
        clip_out='xsel --output'
        clip_in='xsel --input'
      else
        echo "Error: $0: Can not find program to handle clipboard; Need \`xclip\` or \`xsel\`." >&2
        exit 5
      fi
      ;;
    wayland)
      if [ -x "$(command -v wl-paste)" ] ; then
        clip_out='wl-paste'
        clip_in='wl-copy'
      else
        echo "Error: $0: Can not find program to handle clipboard; Need \`wl-clipboard\`." >&2
        exit 5
      fi
      ;;
    tty)
      echo "Error: $0: Can not do clipboard without x11 or wayland; Session type: tty." >&2
      exit 5
      ;;
    *)
      echo "Error: $0: Can not do clipboard without x11 or wayland; Session type: $XDG_SESSION_TYPE." >&2
      exit 5
      ;;
  esac

  clipboard_previous="$($clip_out 2>/dev/null)"

  echo "$output" | head -n1 | tr -d '\n' | $clip_in

  if [ -z "$norestore" ] && [ -z "$otp" ] ; then
    if [ -z "$quiet" ] ; then
      echo "Copied $original_name to clipboard. Will clear in 45 seconds. Press Enter to clear now."
    fi
    timeout --foreground 45 head -n1 >/dev/null 2>&1
    [ $? -eq 1 ] && timeout 45 head -n1 > /dev/null 2>&1
    printf '%s' "$clipboard_previous" | $clip_in
  fi

else
  echo "$output"
fi

