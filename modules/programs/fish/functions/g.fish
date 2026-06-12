function g --description "General git function for adding, commiting, and pushing"
  argparse 'f/force' 'a/amend' 'c/current-directory' 'l/long' -- $argv

  if test (count $argv) -eq 0
    set _flag_amend true
  end
  if set -q _flag_amend
    set _flag_force true
  end

  set parse_flags
  if not set -q _flag_long
    set -a parse_flags --quiet
  end

  set commit_flags
  if set -q _flag_amend
    set -a commit_flags --amend
  end
  if not set -q _flag_long
    set -a commit_flags -q
  end
  # -m last so the message in $argv lands directly after it
  if test (count $argv) -eq 0
    set -a commit_flags --no-edit
  else
    set -a commit_flags -m
  end

  set push_flags
  if set -q _flag_force
    set -a push_flags --force-with-lease
  end
  if not set -q _flag_long
    set -a push_flags -q
  end

  if set -q _flag_current_directory
    set git_root "."
  else
    set git_root (git rev-parse --show-toplevel $parse_flags)
    or return 1
  end
  set git_all "$git_root/*"

  # Redirections can't live in a variable, so branch instead of using a flag
  if set -q _flag_long
    git add $git_all
  else
    git add $git_all 1>/dev/null
  end
  or return 1

  git commit $commit_flags $argv
  or return 1

  git push $push_flags
  or return 1
end
