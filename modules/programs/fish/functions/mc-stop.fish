function mc-stop --description "Stop the specified minecraft server in systemd"
  if test (count $argv) -eq 0
    echo "Usage: mc-stop <server-name>"
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

  sudo systemctl stop $service

  if test $status -eq 0
    echo "Server '$server' is down"
  else
    echo "Failed to stop '$server' -- check logs with: journalctl -u $service -f"
    return 1
  end
end
