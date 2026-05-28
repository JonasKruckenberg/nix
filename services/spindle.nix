{ inputs, ... }:
{
  imports = [
    inputs.tangled.nixosModules.spindle
  ];

  virtualisation.docker.enable = true;

  services.tangled.spindle = {
    enable = true;
    server = {
      hostname = "spindle.jonaskruckenberg.ts.net";
      listenAddr = "127.0.0.1:6555";
      owner = "did:plc:wur5mmsnhlocanyqtus3oex5";
    };
    pipelines = {
      workflowTimeout = "45m";
      maxJobMemoryMb = 12288;
    };
  };
}
