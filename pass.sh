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
  clipboard_previous="$(xclip -out)"

  echo "$output" | head -n1 | xclip -in -rmlastnl

  if [ -z "$norestore" ] && [ -z "$otp" ] ; then
    if [ -z "$quiet" ] ; then
      echo "Copied $original_name to clipboard. Will clear in 45 seconds. Press Enter to clear now."
    fi
    timeout 45 head -n1 > /dev/null
    printf '%s' "$clipboard_previous" | xclip -in
  fi

else
  echo "$output"

fi

