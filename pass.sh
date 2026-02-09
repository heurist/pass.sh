#!/bin/sh

while :; do
  case "$1" in
    otp)
      otp=1
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

if [ "${passfile##*.}" != 'gpg' ] ; then
  passfile="${passfile}.gpg"
fi

real_passfile=$(realpath "${passfile}" 2>/dev/null)
if [ ! -f "$real_passfile" ] ; then
  real_passfile=$(realpath "$HOME/.password-store/${passfile}" 2>/dev/null)
  if [ ! -f "$real_passfile" ] ; then
    echo "Error: '$original_name' not found in password-store." >&2
    exit 1
  fi
fi


output="$(gpg --quiet --decrypt "$real_passfile")"

if [ -n "$otp" ] ; then
  output="$(
    echo "$output" | \
      sed -n -r '/^otpauth/s/^.+secret=([^&]+).*$/\1/p'
    )"
    if [ -z "$output" ] ; then
      echo "Error: $0: otpauth not found in $original_name" >&2
      exit 3
    fi
    output="$(
      echo "$output" | oathtool --base32 --totp -
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

