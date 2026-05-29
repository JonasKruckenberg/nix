{ inputs, config, ... }:
# tsnsrv registers each entry under `services` as its own tsnet node, giving
# us a separate MagicDNS hostname per service without renaming the host.
{
  imports = [
    inputs.tsnsrv.nixosModules.default
  ];

  age.secrets.tsnsrv-authkey.file = ../secrets/tsnsrv-authkey.age;

  services.tsnsrv = {
    enable = true;
    defaults.authKeyPath = config.age.secrets.tsnsrv-authkey.path;
    services.spindle = {
      toURL = "http://127.0.0.1:6555";
      funnel = true;
      stripPrefix = false;
      prefixes = [
        "tailnet:/" # full, unrestricted access from within the tailnet
        "funnel:/events" # pipeline event stream (appview event consumer)
        "funnel:/logs/" # pipeline log output (appview log websocket)
        "funnel:/xrpc/" # appview control plane: verify, retry, secrets
      ];
    };
  };
}
