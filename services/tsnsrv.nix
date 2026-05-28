{ inputs, ... }:
# tsnsrv registers each entry under `services` as its own tsnet node, giving
# us a separate MagicDNS hostname per service without renaming the host.
#
# Bootstrap (one-time):
#   1. In the tailnet admin console, mint a reusable, pre-approved auth key
#      and enable Funnel for the tag/user the key belongs to.
#   2. On ardmore:
#        sudo install -d -m 700 -o tsnsrv -g tsnsrv /var/lib/tsnsrv
#        printf 'tskey-auth-...\n' | sudo tee /var/lib/tsnsrv/authkey > /dev/null
#        sudo chmod 600 /var/lib/tsnsrv/authkey
#        sudo systemctl restart tsnsrv-spindle
{
  imports = [
    inputs.tsnsrv.nixosModules.default
  ];

  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = "/var/lib/tsnsrv/authkey";
    services.spindle = {
      toURL = "http://127.0.0.1:6555";
      funnel = true;
    };
  };
}
