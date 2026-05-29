let
  jonas = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4p5xyCPbCfuOf+bCNXTi0pcDNXsAdcABSEcgx/WujU";
  ardmore = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGUKx/lzVEe1tJbz4Dcx58PoNMGvQ8O3zjKiJjasDJbs";
  all = [
    jonas
    ardmore
  ];
in
{
  "attic-server.env.age".publicKeys = all;
  "tsnsrv-authkey.age".publicKeys = all;
}
