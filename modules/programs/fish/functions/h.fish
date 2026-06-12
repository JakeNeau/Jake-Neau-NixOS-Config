function h --description "Hibernate the machine"
  if test (uname) = Darwin
    # macOS has no one-shot hibernate command: temporarily switch the sleep
    # mode to full hibernation (25), sleep, then restore the old mode once
    # the machine wakes back up and the function resumes
    set -l previous_mode (pmset -g | awk '/hibernatemode/ {print $2}')
    sudo pmset -a hibernatemode 25
    or begin
      echo "h: could not switch hibernatemode, not hibernating" >&2
      return 1
    end
    sudo pmset sleepnow
    sudo pmset -a hibernatemode $previous_mode
  else
    systemctl hibernate
  end
end
