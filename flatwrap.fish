function flatwrap
  set -l cfg $argv; set -l app $argv
  if test (count $argv) -ne 2
    echo "Usage: flatpak-wg <config> <app>"; return 1
  end
  echo "DEBUG: Config='$cfg' App='$app'"
  set -l abs (realpath -- $cfg)
  if test $status -ne 0; echo "Path error"; return 1; end
  if not test -f $abs; echo "File not found: $abs"; return 1; end
  set -l ns "fwg-$(date +%s)-$app"
  doas ip netns add $ns
  if not doas ip netns exec $ns wg-quick up $abs
    doas ip netns del $ns; echo "WG failed"; return 1
  end
  if not doas ip netns exec $ns wg show >/dev/null 2>&1
    doas ip netns exec $ns wg-quick down $abs; doas ip netns del $ns; echo "WG not active"; return 1
  end
  echo "Tunnel up. Running $app..."
  doas ip netns exec $ns flatpak run $app
  set -l ret $status
  doas ip netns del $ns
  return $ret
end
