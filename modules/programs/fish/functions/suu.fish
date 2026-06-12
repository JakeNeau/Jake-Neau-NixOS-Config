function suu --description "Run sudo as the current user"
  sudo SSH_AUTH_SOCK="$SSH_AUTH_SOCK" $argv
end
