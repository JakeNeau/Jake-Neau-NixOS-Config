function mc-logs --description "List the systemd logs for the specified server"
  argparse 'f/follow' -- $argv

  if test (count $argv) -eq 0
    echo "Usage: mc-logs <server-name> [flags]"
    echo "Options:"
    echo "  -f, --follow    Follow log output"
    echo ""
    mc-list
    return 1
  end

  set server $argv[1]
  set service "minecraft-server-$server"

  if not systemctl list-unit-files --type=service --all --no-legend | grep -q "$service"
    echo "Error: server '$server' not found"
    echo ""
    mc-list
    return 1
  end

  if set -q _flag_follow
    journalctl -u $service -f
  else
    journalctl -u $service
  end
end
