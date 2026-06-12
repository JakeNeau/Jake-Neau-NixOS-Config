function mc-list --description "Lists all available minecraft servers in systemd"
  set units (systemctl list-unit-files --type=service --all --no-legend | grep minecraft-server | awk '{print $1}')

  if test (count $units) -eq 0
    echo "No minecraft servers are installed on this host"
    return
  end

  echo "Available servers:"
  for unit in $units
    set name (string replace --regex 'minecraft-server-(.+)\.service' '$1' $unit)
    set server_status (systemctl is-active $unit)
    echo "  $name ($server_status)"
  end
end
